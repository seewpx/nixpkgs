{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.gitolite;
  # Use writeTextDir to not leak Nix store hash into file name
  pubkeyFile = (pkgs.writeTextDir "gitolite-admin.pub" cfg.adminPubkey) + "/gitolite-admin.pub";
  hooks = lib.concatMapStrings (hook: "${hook} ") cfg.commonHooks;
in
{
  options = {
    services.gitolite = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable gitolite management under the
          `gitolite` user. After
          switching to a configuration with Gitolite enabled, you can
          then run `git clone gitolite@host:gitolite-admin.git` to manage it further.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/gitolite";
        description = ''
          The gitolite home directory used to store all repositories. If left as the default value
          this directory will automatically be created before the gitolite server starts, otherwise
          the sysadmin is responsible for ensuring the directory exists with appropriate ownership
          and permissions.
        '';
      };

      adminPubkey = lib.mkOption {
        type = lib.types.str;
        description = ''
          Initial administrative public key for Gitolite. This should
          be an SSH Public Key. Note that this key will only be used
          once, upon the first initialization of the Gitolite user.
          The key string cannot have any line breaks in it.
        '';
      };

      enableGitAnnex = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable git-annex support. Uses the `extraGitoliteRc` option
          to apply the necessary configuration.
        '';
      };

      commonHooks = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = ''
          A list of custom git hooks that get copied to `~/.gitolite/hooks/common`.
        '';
      };

      extraGitoliteRc = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = lib.literalExpression ''
          '''
            $RC{UMASK} = 0027;
            $RC{SITE_INFO} = 'This is our private repository host';
            push( @{$RC{ENABLE}}, 'Kindergarten' ); # enable the command/feature
            @{$RC{ENABLE}} = grep { $_ ne 'desc' } @{$RC{ENABLE}}; # disable the command/feature
          '''
        '';
        description = ''
          Extra configuration to append to the default `~/.gitolite.rc`.

          This should be Perl code that modifies the `%RC`
          configuration variable. The default `~/.gitolite.rc`
          content is generated by invoking `gitolite print-default-rc`,
          and extra configuration from this option is appended to it. The result
          is placed to Nix store, and the `~/.gitolite.rc` file
          becomes a symlink to it.

          If you already have a customized (or otherwise changed)
          `~/.gitolite.rc` file, NixOS will refuse to replace
          it with a symlink, and the `gitolite-init` initialization service
          will fail. In this situation, in order to use this option, you
          will need to take any customizations you may have in
          `~/.gitolite.rc`, convert them to appropriate Perl
          statements, add them to this option, and remove the file.

          See also the `enableGitAnnex` option.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "gitolite";
        description = ''
          Gitolite user account. This is the username of the gitolite endpoint.
        '';
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "Gitolite user";
        description = ''
          Gitolite user account's description.
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "gitolite";
        description = ''
          Primary group of the Gitolite user account.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      manageGitoliteRc = cfg.extraGitoliteRc != "";
      rcDir = pkgs.runCommand "gitolite-rc" { preferLocalBuild = true; } rcDirScript;
      rcDirScript = ''
        mkdir "$out"
        export HOME=temp-home
        mkdir -p "$HOME/.gitolite/logs" # gitolite can't run without it
        '${pkgs.gitolite}'/bin/gitolite print-default-rc >>"$out/gitolite.rc.default"
        cat <<END >>"$out/gitolite.rc"
        # This file is managed by NixOS.
        # Use services.gitolite options to control it.

        END
        cat "$out/gitolite.rc.default" >>"$out/gitolite.rc"
      ''
      + lib.optionalString (cfg.extraGitoliteRc != "") ''
        echo -n ${lib.escapeShellArg ''

          # Added by NixOS:
          ${lib.removeSuffix "\n" cfg.extraGitoliteRc}

          # per perl rules, this should be the last line in such a file:
          1;
        ''} >>"$out/gitolite.rc"
      '';
    in
    {
      services.gitolite.extraGitoliteRc = lib.optionalString cfg.enableGitAnnex ''
        # Enable git-annex support:
        push( @{$RC{ENABLE}}, 'git-annex-shell ua');
      '';

      users.users.${cfg.user} = {
        description = cfg.description;
        home = cfg.dataDir;
        uid = config.ids.uids.gitolite;
        group = cfg.group;
        useDefaultShell = true;
      };
      users.groups.${cfg.group}.gid = config.ids.gids.gitolite;

      systemd.services.gitolite-init = {
        description = "Gitolite initialization";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = cfg.dataDir;

        environment = {
          GITOLITE_RC = ".gitolite.rc";
          GITOLITE_RC_DEFAULT = "${rcDir}/gitolite.rc.default";
        };

        serviceConfig = lib.mkMerge [
          (lib.mkIf (cfg.dataDir == "/var/lib/gitolite") {
            StateDirectory = "gitolite gitolite/.gitolite gitolite/.gitolite/logs";
            StateDirectoryMode = "0750";
          })
          {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = "~";
            RemainAfterExit = true;
          }
        ];

        path = [
          pkgs.gitolite
          pkgs.git
          pkgs.perl
          pkgs.bash
          pkgs.diffutils
          config.programs.ssh.package
        ];
        script =
          let
            rcSetupScriptIfCustomFile =
              if manageGitoliteRc then
                ''
                  cat <<END
                  <3>ERROR: NixOS can't apply declarative configuration
                  <3>to your .gitolite.rc file, because it seems to be
                  <3>already customized manually.
                  <3>See the services.gitolite.extraGitoliteRc option
                  <3>in "man configuration.nix" for more information.
                  END
                  # Not sure if the line below addresses the issue directly or just
                  # adds a delay, but without it our error message often doesn't
                  # show up in `systemctl status gitolite-init`.
                  journalctl --flush
                  exit 1
                ''
              else
                ''
                  :
                '';
            rcSetupScriptIfDefaultFileOrStoreSymlink =
              if manageGitoliteRc then
                ''
                  ln -sf "${rcDir}/gitolite.rc" "$GITOLITE_RC"
                ''
              else
                ''
                  [[ -L "$GITOLITE_RC" ]] && rm -f "$GITOLITE_RC"
                '';
          in
          ''
            if ( [[ ! -e "$GITOLITE_RC" ]] && [[ ! -L "$GITOLITE_RC" ]] ) ||
               ( [[ -f "$GITOLITE_RC" ]] && diff -q "$GITOLITE_RC" "$GITOLITE_RC_DEFAULT" >/dev/null ) ||
               ( [[ -L "$GITOLITE_RC" ]] && [[ "$(readlink "$GITOLITE_RC")" =~ ^/nix/store/ ]] )
            then
          ''
          + rcSetupScriptIfDefaultFileOrStoreSymlink
          + ''
            else
          ''
          + rcSetupScriptIfCustomFile
          + ''
            fi

            if [ ! -d repositories ]; then
              gitolite setup -pk ${pubkeyFile}
            fi
            if [ -n "${hooks}" ]; then
              cp -f ${hooks} .gitolite/hooks/common/
              chmod +x .gitolite/hooks/common/*
            fi
            gitolite setup # Upgrade if needed
          '';
      };

      environment.systemPackages = [
        pkgs.gitolite
        pkgs.git
      ]
      ++ lib.optional cfg.enableGitAnnex pkgs.git-annex;
    }
  );
}

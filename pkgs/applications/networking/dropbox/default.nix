{
  stdenv,
  lib,
  buildFHSEnv,
  writeScript,
  makeDesktopItem,
}:

# Dropbox client to bootstrap installation.
# The client is self-updating, so the actual version may be newer.
let
  version =
    {
      x86_64-linux = "217.4.4417";
      i686-linux = "206.3.6386";
    }
    .${stdenv.hostPlatform.system} or "";

  arch =
    {
      x86_64-linux = "x86_64";
      i686-linux = "x86";
    }
    .${stdenv.hostPlatform.system};

  installer = "https://clientupdates.dropboxstatic.com/dbx-releng/client/dropbox-lnx.${arch}-${version}.tar.gz";

  desktopItem = makeDesktopItem {
    name = "dropbox";
    exec = "dropbox";
    comment = "Sync your files across computers and to the web";
    desktopName = "Dropbox";
    genericName = "File Synchronizer";
    categories = [
      "Network"
      "FileTransfer"
    ];
    startupNotify = false;
    icon = "dropbox";
  };
in

buildFHSEnv {
  inherit version;
  pname = "dropbox";

  # The dropbox-cli command `dropbox start` starts the dropbox daemon in a
  # separate session, and wants the daemon to outlive the launcher.  Enabling
  # `--die-with-parent` defeats this and causes the daemon to exit when
  # dropbox-cli exits.
  dieWithParent = false;

  # dropbox-cli (i.e. nautilus-dropbox) needs the PID to confirm dropbox is running.
  # Dropbox's internal limit-to-one-instance check also relies on the PID.
  unsharePid = false;

  targetPkgs =
    pkgs:
    with pkgs;
    with xorg;
    [
      libICE
      libSM
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrender
      libXmu
      libXxf86vm
      libGL
      libxcb
      xkeyboardconfig
      curl
      dbus
      firefox-bin
      fontconfig
      freetype
      gcc
      glib
      gnutar
      gtk3
      libxml2
      libxslt
      procps
      zlib
      libgbm
      libxshmfence
      libpthreadstubs
      libappindicator
    ];

  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    cp "${desktopItem}/share/applications/"* $out/share/applications
  '';

  runScript = writeScript "install-and-start-dropbox" ''
    export BROWSER=firefox

    set -e

    do_install=
    if ! [ -d "$HOME/.dropbox-dist" ]; then
        do_install=1
    else
        installed_version=$(cat "$HOME/.dropbox-dist/VERSION")
        latest_version=$(printf "${version}\n$installed_version\n" | sort -rV | head -n 1)
        if [ "x$installed_version" != "x$latest_version" ]; then
            do_install=1
        fi
    fi

    if [ -n "$do_install" ]; then
        installer=$(mktemp)
        # Dropbox is not installed.
        # Download and unpack the client. If a newer version is available,
        # the client will update itself when run.
        curl '${installer}' >"$installer"
        pkill dropbox || true
        rm -fr "$HOME/.dropbox-dist"
        tar -C "$HOME" -x -z -f "$installer"
        rm "$installer"
    fi

    exec "$HOME/.dropbox-dist/dropboxd" "$@"
  '';

  meta = {
    description = "Online stored folders (daemon version)";
    homepage = "https://www.dropbox.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ttuegel ];
    platforms = [
      "i686-linux"
      "x86_64-linux"
    ];
    mainProgram = "dropbox";
  };
}

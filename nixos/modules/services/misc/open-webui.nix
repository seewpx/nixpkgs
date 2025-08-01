{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;

  cfg = config.services.open-webui;
in
{
  options = {
    services.open-webui = {
      enable = lib.mkEnableOption "Open-WebUI server";
      package = lib.mkPackageOption pkgs "open-webui" { };

      stateDir = lib.mkOption {
        type = types.path;
        default = "/var/lib/open-webui";
        example = "/home/foo";
        description = "State directory of Open-WebUI.";
      };

      host = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = ''
          The host address which the Open-WebUI server HTTP interface listens to.
        '';
      };

      port = lib.mkOption {
        type = types.port;
        default = 8080;
        example = 11111;
        description = ''
          Which port the Open-WebUI server listens to.
        '';
      };

      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = {
          SCARF_NO_ANALYTICS = "True";
          DO_NOT_TRACK = "True";
          ANONYMIZED_TELEMETRY = "False";
        };
        example = ''
          {
            OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
            # Disable authentication
            WEBUI_AUTH = "False";
          }
        '';
        description = ''
          Extra environment variables for Open-WebUI.
          For more details see <https://docs.openwebui.com/getting-started/advanced-topics/env-configuration/>
        '';
      };

      environmentFile = lib.mkOption {
        description = ''
          Environment file to be passed to the systemd service.
          Useful for passing secrets to the service to prevent them from being
          world-readable in the Nix store.
        '';
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/var/lib/secrets/openWebuiSecrets";
      };

      openFirewall = lib.mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to open the firewall for Open-WebUI.
          This adds `services.open-webui.port` to `networking.firewall.allowedTCPPorts`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.open-webui = {
      description = "User-friendly WebUI for LLMs";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        STATIC_DIR = ".";
        DATA_DIR = ".";
        HF_HOME = ".";
        SENTENCE_TRANSFORMERS_HOME = ".";
        WEBUI_URL = "http://localhost:${toString cfg.port}";
      }
      // cfg.environment;

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} serve --host \"${cfg.host}\" --port ${toString cfg.port}";
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        WorkingDirectory = cfg.stateDir;
        StateDirectory = "open-webui";
        RuntimeDirectory = "open-webui";
        RuntimeDirectoryMode = "0755";
        PrivateTmp = true;
        DynamicUser = true;
        DevicePolicy = "closed";
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # onnxruntime/capi/onnxruntime_pybind11_state.so: cannot enable executable stack as shared object requires: Permission Denied
        PrivateUsers = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProcSubset = "all"; # Error in cpuinfo: failed to parse processor information from /proc/cpuinfo
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        ProtectClock = true;
        ProtectProc = "invisible";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        SupplementaryGroups = [ "render" ]; # for rocm to access /dev/dri/renderD* devices
        DeviceAllow = [
          # CUDA
          # https://docs.nvidia.com/dgx/pdf/dgx-os-5-user-guide.pdf
          "char-nvidiactl"
          "char-nvidia-caps"
          "char-nvidia-frontend"
          "char-nvidia-uvm"
          # ROCm
          "char-drm"
          "char-fb"
          "char-kfd"
          # WSL (Windows Subsystem for Linux)
          "/dev/dxg"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };
  };

  meta.maintainers = with lib.maintainers; [ shivaraj-bh ];
}

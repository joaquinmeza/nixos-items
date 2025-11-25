{ config, lib, pkgs, ... }:

let
  cfg = config.services.mailrise;

  # Mailrise package (not in nixpkgs)
  mailrise = pkgs.python3.pkgs.buildPythonApplication rec {
    pname = "mailrise";
    version = "1.4.0";
    format = "setuptools";

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-BKl5g4R9L5IrygMd9Vbi20iF2APpxSSfKxU25naPGTc=";
    };

    nativeBuildInputs = with pkgs.python3.pkgs; [
      setuptools
      setuptools-scm
    ];

    propagatedBuildInputs = with pkgs.python3.pkgs; [
      apprise
      aiosmtpd
      pyyaml
    ];

    doCheck = false;
    pythonImportsCheck = [ "mailrise" ];

    meta = with lib; {
      description = "An SMTP gateway for Apprise notifications";
      homepage = "https://mailrise.xyz";
      license = licenses.mit;
    };
  };

  # Default configuration file
  defaultConfig = pkgs.writeText "mailrise.conf" ''
    # Mailrise configuration
    # See https://mailrise.xyz for full configuration options

    configs:
      # Example configuration - replace with your notification services
      # example:
      #   urls:
      #     - pover://USER_KEY@TOKEN
      #     - discord://WEBHOOK_ID/WEBHOOK_TOKEN

    listen:
      host: ${cfg.listenAddress}
      port: ${toString cfg.port}
  '';

in
{
  options.services.mailrise = {
    enable = lib.mkEnableOption "Mailrise SMTP notification gateway";

    package = lib.mkOption {
      type = lib.types.package;
      default = mailrise;
      description = "The Mailrise package to use.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = defaultConfig;
      description = ''
        Path to the Mailrise YAML configuration file.
        See https://mailrise.xyz for configuration options.
      '';
      example = lib.literalExpression "/etc/mailrise/config.yaml";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to listen on for SMTP connections.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8025;
      description = "Port to listen on for SMTP connections.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mailrise";
      description = "User account under which Mailrise runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "mailrise";
      description = "Group under which Mailrise runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Mailrise SMTP gateway user";
    };

    users.groups.${cfg.group} = {};

    # Systemd service
    systemd.services.mailrise = {
      description = "Mailrise SMTP notification gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/mailrise ${cfg.configFile}";
        Restart = "on-failure";
        RestartSec = "5s";

        # State directory for runtime-generated configs
        StateDirectory = "mailrise";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Open firewall port if listening on all interfaces
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.listenAddress == "0.0.0.0") [ cfg.port ];
  };
}

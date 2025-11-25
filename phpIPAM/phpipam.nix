{ config, lib, pkgs, ... }:

let
  # phpIPAM version and source
  version = "1.7.0";
  phpipamSrc = pkgs.fetchFromGitHub {
    owner = "phpipam";
    repo = "phpipam";
    rev = "v${version}";
    sha256 = "sha256-zcBD/I/SskEF9scAlZs4lr6neU8yHIjoqH2PGEsNuOM=";
  };

  # Installation directory
  webroot = "/var/lib/phpipam";

  # PHP package with required extensions
  php = pkgs.php83.buildEnv {
    extensions = { enabled, all }: enabled ++ (with all; [
      gmp        # IPv6 network calculations
      ldap       # Active Directory integration
      mbstring   # Multi-byte string handling
      mysqli     # MySQL connectivity
      openssl    # SSL/TLS
      pdo        # Database abstraction
      pdo_mysql  # MySQL PDO driver
      session    # Session management
      sockets    # Socket support
      # Optional but useful
      pcntl      # Network scanning
      simplexml  # RIPE queries and API
    ]);
    extraConfig = ''
      memory_limit = 256M
      upload_max_filesize = 16M
      post_max_size = 16M
      max_execution_time = 300
    '';
  };

  user = "phpipam";
  group = "phpipam";

  # Database configuration
  dbName = "phpipam";
  dbUser = "phpipam";

in
{
  # phpIPAM - IP address management (IPAM) tool
  # https://phpipam.net/
  # Lightweight, web-based IP address management

  # Secrets for database password
  # Adjust sopsFile path to match your secrets location
  sops.secrets."phpipam/db_password" = {
    sopsFile = /path/to/your/secrets/common.yaml;
    key = "phpipam/db_password";
    owner = user;
    group = group;
  };

  # Create phpipam user
  users.users.${user} = {
    isSystemUser = true;
    group = group;
    home = webroot;
  };
  users.groups.${group} = {};

  # MySQL database
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ dbName ];
    ensureUsers = [{
      name = dbUser;
      ensurePermissions = {
        "${dbName}.*" = "ALL PRIVILEGES";
      };
    }];
  };

  # PHP-FPM pool for phpIPAM
  services.phpfpm.pools.phpipam = {
    inherit user group;
    phpPackage = php;

    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
      "pm.max_requests" = 500;
    };
  };

  # nginx virtual host
  # Replace with your actual domain
  services.nginx.virtualHosts."ipam.example.com" = {
    forceSSL = true;
    useACMEHost = "example.com";

    root = webroot;

    locations."/" = {
      index = "index.php";
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };

    locations."~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.phpipam.socket};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };

    # Deny access to sensitive files
    locations."~ /\\.".extraConfig = "deny all;";
    locations."~ /config.php".extraConfig = "deny all;";
  };

  # Copy phpIPAM source to webroot and set up configuration
  systemd.services.phpipam-setup = {
    description = "phpIPAM setup and initialization";
    wantedBy = [ "multi-user.target" ];
    after = [ "mysql.service" ];
    requires = [ "mysql.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = group;
    };

    script = ''
      # Create webroot if it doesn't exist
      mkdir -p ${webroot}

      # Copy phpIPAM files if not already present
      if [ ! -f ${webroot}/index.php ]; then
        echo "Installing phpIPAM ${version}..."
        ${pkgs.rsync}/bin/rsync -a --chmod=u+w ${phpipamSrc}/ ${webroot}/
      fi

      # Create config.php from config.dist.php if it doesn't exist
      if [ ! -f ${webroot}/config.php ]; then
        echo "Creating initial config.php..."
        cp ${webroot}/config.dist.php ${webroot}/config.php

        # Update database credentials in config.php
        DB_PASS=$(cat ${config.sops.secrets."phpipam/db_password".path})

        sed -i "s/^\$db\['host'\] = 'localhost';/\$db['host'] = 'localhost';/" ${webroot}/config.php
        sed -i "s/^\$db\['user'\] = 'phpipam';/\$db['user'] = '${dbUser}';/" ${webroot}/config.php
        sed -i "s/^\$db\['pass'\] = 'phpipamadmin';/\$db['pass'] = '$DB_PASS';/" ${webroot}/config.php
        sed -i "s/^\$db\['name'\] = 'phpipam';/\$db['name'] = '${dbName}';/" ${webroot}/config.php
      fi

      # Set correct permissions
      chmod -R u+w ${webroot}
    '';
  };

  # Set MySQL password for phpipam user
  # This runs after MySQL is up and the user is created
  systemd.services.phpipam-db-setup = {
    description = "Set phpIPAM database password";
    wantedBy = [ "multi-user.target" ];
    after = [ "mysql.service" "phpipam-setup.service" ];
    requires = [ "mysql.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      DB_PASS=$(cat ${config.sops.secrets."phpipam/db_password".path})
      ${pkgs.mariadb}/bin/mysql -u root <<EOF
        ALTER USER '${dbUser}'@'localhost' IDENTIFIED BY '$DB_PASS';
        FLUSH PRIVILEGES;
      EOF

      echo "Database password set for ${dbUser}"
    '';
  };

  # Ensure webroot exists with correct permissions
  systemd.tmpfiles.rules = [
    "d ${webroot} 0750 ${user} ${group} -"
  ];
}

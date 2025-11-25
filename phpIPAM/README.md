# phpIPAM - NixOS Module

This repository contains a custom NixOS module for deploying phpIPAM, a web-based IP address management (IPAM) tool, as a native NixOS service without Docker or Podman.

## What is phpIPAM?

phpIPAM is an open-source web IP address management application (IPAM). It's designed to be lightweight, modern, and useful for managing IP addresses in small to medium-sized networks.

**Key Features:**
- **IP Address Management**: Track IPv4 and IPv6 addresses, subnets, and VLANs
- **Network Discovery**: Automatic network scanning and device discovery
- **VLAN Management**: Organize networks by VLANs
- **Visual Subnet Display**: Hierarchical subnet visualization
- **API Access**: RESTful API for automation and integration
- **LDAP/AD Integration**: Authenticate users via Active Directory
- **Multi-tenancy**: Support for multiple organizations/tenants
- **RIPE Integration**: Query RIPE database for network information

phpIPAM is perfect for homelabs, small businesses, and MSPs who need to track IP allocations without enterprise-grade complexity.

## Usage in NixOS

### As a NixOS Service Module

This module creates a complete phpIPAM deployment using native NixOS primitives:
- **PHP-FPM** for application runtime
- **MySQL/MariaDB** for data storage
- **nginx** for web server and SSL termination
- **sops-nix** for secrets management

Example usage:

```nix
# In your NixOS configuration or homelab service allocation
{ config, pkgs, ... }:

{
  imports = [
    /path/to/phpIPAM/phpipam.nix
  ];

  # Required: Set up sops secret for database password
  sops.secrets."phpipam/db_password" = {
    sopsFile = ./secrets/common.yaml;
    owner = "phpipam";
    group = "phpipam";
  };

  # nginx must be enabled (can be in another module)
  services.nginx.enable = true;

  # ACME certificate (wildcard recommended)
  security.acme.certs."example.com" = {
    # ... your ACME config
  };
}
```

### With Colmena (Multi-Host Deployment)

```nix
# homelab/hosts.nix
{
  your-server = [
    ./services/phpipam.nix
    # ... other services
  ];
}
```

### Standalone System Configuration

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    /path/to/phpIPAM/phpipam.nix
  ];

  # ... rest of configuration
}
```

## How It Works

### Installation Process

The module automatically:

1. **Fetches phpIPAM source** from GitHub (v1.7.0)
   - Uses `fetchFromGitHub` with verified SHA256 hash
   - No manual downloads required

2. **Creates PHP-FPM pool** with required extensions:
   - Core: `pdo`, `pdo_mysql`, `session`, `sockets`, `openssl`
   - Features: `gmp` (IPv6), `ldap` (AD), `mbstring`, `pcntl`, `simplexml`
   - Optimized settings: 256MB memory, 300s execution time

3. **Sets up MySQL database**:
   - Creates `phpipam` database automatically
   - Creates `phpipam` user with proper permissions
   - Sets password from sops secret

4. **Deploys application files**:
   - Copies source to `/var/lib/phpipam`
   - Generates `config.php` with database credentials
   - Sets correct file permissions

5. **Configures nginx**:
   - Virtual host at `ipam.example.com` (customizable)
   - SSL via ACME (Let's Encrypt)
   - PHP-FPM integration
   - Security headers and file restrictions

### File Structure

After deployment:
```
/var/lib/phpipam/              # Application root (webroot)
├── index.php                   # Main entry point
├── config.php                  # Generated database config
├── app/                        # Application code
├── db/                         # Database schema
├── api/                        # REST API
└── css/, js/, ...              # Web assets

/run/secrets/                   # sops-managed secrets
└── phpipam/db_password         # Database password (0400)

/run/phpfpm/                    # PHP-FPM runtime
└── phpipam.sock                # Unix socket for nginx
```

### Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    nginx (443)                          │
│              ipam.example.com                        │
│              (SSL via ACME)                             │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼ (unix socket)
┌─────────────────────────────────────────────────────────┐
│              PHP-FPM Pool (phpipam)                     │
│  - PHP 8.3 with extensions                              │
│  - Dynamic process manager                              │
│  - User: phpipam, Group: phpipam                        │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼ (TCP 3306)
┌─────────────────────────────────────────────────────────┐
│              MariaDB (MySQL)                            │
│  - Database: phpipam                                    │
│  - User: phpipam                                        │
│  - Password: from sops secret                           │
└─────────────────────────────────────────────────────────┘
```

## Configuration Options

### Customizing the Module

You can modify these variables in `phpipam.nix`:

```nix
let
  version = "1.7.0";              # phpIPAM version
  webroot = "/var/lib/phpipam";   # Installation directory
  dbName = "phpipam";             # Database name
  dbUser = "phpipam";             # Database user
  user = "phpipam";               # System user
  group = "phpipam";              # System group
```

### Changing the Domain

Edit the nginx virtual host section:

```nix
services.nginx.virtualHosts."YOUR-DOMAIN-HERE" = {
  forceSSL = true;
  useACMEHost = "example.com";
  # ... rest of config
};
```

### PHP Settings

Adjust PHP limits in the `php.buildEnv` extraConfig:

```nix
extraConfig = ''
  memory_limit = 256M            # Memory per request
  upload_max_filesize = 16M      # Max file upload
  post_max_size = 16M            # Max POST size
  max_execution_time = 300       # Script timeout (seconds)
'';
```

### PHP-FPM Pool Tuning

Modify process manager settings:

```nix
services.phpfpm.pools.phpipam.settings = {
  "pm.max_children" = 32;        # Max concurrent processes
  "pm.start_servers" = 2;        # Initial processes
  "pm.min_spare_servers" = 2;    # Minimum idle processes
  "pm.max_spare_servers" = 4;    # Maximum idle processes
  "pm.max_requests" = 500;       # Restart after N requests
};
```

## Deployment Instructions

### Prerequisites

1. **sops-nix configured** with age keys
2. **nginx module** enabled on the target host
3. **ACME certificate** for your domain (wildcard recommended)
4. **DNS entry** pointing to your server

### Step 1: Add Secret

```bash
# Generate a secure database password
nix run nixpkgs#openssl -- rand -base64 32

# Edit your secrets file
sops secrets/common.yaml
```

Add this entry:
```yaml
phpipam:
  db_password: <your-generated-password>
```

### Step 2: Configure DNS

Add a DNS record (via Blocky, Pi-hole, or your DNS provider):
```
ipam.example.com → <server-ip>
```

### Step 3: Deploy

```bash
# Single host deployment
sudo nixos-rebuild switch

# Or with Colmena (multi-host)
colmena apply --impure --on your-server
```

### Step 4: Initial Setup

1. Navigate to `https://ipam.example.com`
2. Click **"New phpipam installation"**
3. Choose **"Automatic database installation"**
4. The database will be initialized automatically
5. Default credentials: `Admin` / `ipamadmin`
6. **Change the password immediately!**

### Step 5: Configuration

1. Go to **Administration → Settings**
2. Configure:
   - Site title
   - Site URL
   - Timezone
   - Language
3. Set up LDAP/AD if needed
4. Enable/disable features as required

## Security Considerations

### Database Password

- Stored encrypted in sops secrets file
- Decrypted at activation time to `/run/secrets/`
- Only readable by `phpipam` user (mode 0400)
- Never stored in plain text in Nix store

### File Permissions

- Webroot owned by `phpipam:phpipam`
- `config.php` generated at runtime with credentials
- Sensitive files denied via nginx configuration:
  ```nginx
  location ~ /\. { deny all; }
  location ~ /config.php { deny all; }
  ```

### nginx Security

- SSL/TLS enforced via `forceSSL = true`
- ACME certificates auto-renewed
- PHP files only processed via PHP-FPM (no direct execution)
- Document root restricted to application directory

### Firewall

The module does NOT open firewall ports. nginx should be configured separately:

```nix
networking.firewall.allowedTCPPorts = [ 80 443 ];
```

## Updating phpIPAM

### Updating to a New Version

1. **Check the new version** on [phpIPAM GitHub](https://github.com/phpipam/phpipam/releases)

2. **Update the module**:
   ```nix
   version = "NEW_VERSION";  # e.g., "1.8.0"
   ```

3. **Get the new hash**:
   ```bash
   nix-prefetch-url --unpack https://github.com/phpipam/phpipam/archive/refs/tags/vNEW_VERSION.tar.gz

   # Convert to SRI format
   nix hash convert --hash-algo sha256 <hash-from-above>
   ```

4. **Update the SHA256**:
   ```nix
   sha256 = "sha256-NEW_HASH_HERE";
   ```

5. **Redeploy**:
   ```bash
   sudo nixos-rebuild switch
   # or
   colmena apply --impure --on your-server
   ```

6. **Run database migration** via the web interface if prompted

### Database Backups

Before major updates, backup your database:

```bash
# Manual backup
sudo -u phpipam mysqldump phpipam > phpipam-backup-$(date +%Y%m%d).sql

# Or use a systemd timer for automatic backups
```

## Troubleshooting

### Service Won't Start

Check systemd services:
```bash
sudo systemctl status phpipam-setup
sudo systemctl status phpipam-db-setup
sudo systemctl status phpfpm-phpipam
sudo systemctl status mysql
sudo systemctl status nginx
```

View logs:
```bash
sudo journalctl -u phpipam-setup -f
sudo journalctl -u phpfpm-phpipam -f
sudo journalctl -u nginx -f
```

### 502 Bad Gateway

PHP-FPM not running or socket issues:
```bash
# Check PHP-FPM socket exists
ls -l /run/phpfpm/phpipam.sock

# Restart PHP-FPM
sudo systemctl restart phpfpm-phpipam
```

### Database Connection Failed

Check MySQL credentials:
```bash
# Verify secret is decrypted
sudo cat /run/secrets/phpipam/db_password

# Test database connection
sudo -u phpipam mysql -u phpipam -p phpipam
```

Check database exists:
```bash
sudo mysql -e "SHOW DATABASES LIKE 'phpipam';"
sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User='phpipam';"
```

### Permission Denied Errors

Fix webroot permissions:
```bash
sudo chown -R phpipam:phpipam /var/lib/phpipam
sudo chmod -R u+w /var/lib/phpipam
```

### SSL Certificate Issues

Check ACME certificates:
```bash
sudo systemctl status acme-example.com
ls -l /var/lib/acme/example.com/

# Rebuild certificates if needed
sudo systemctl restart acme-example.com
```

### Missing PHP Extensions

Verify extensions are loaded:
```bash
# Check PHP-FPM pool config
sudo cat /etc/php-fpm.d/phpipam.conf

# Test PHP extensions manually
nix-shell -p php83 --run "php -m | grep -E '(gmp|ldap|mysqli|pdo_mysql)'"
```

## Platform Support

- **Supported**: `x86_64-linux`, `aarch64-linux` (any platform with PHP-FPM support)
- **PHP Version**: 8.3 (configurable to 8.2 or 8.4)
- **Database**: MariaDB (MySQL-compatible)
- **Web Server**: nginx (required)

## Advantages Over Docker Deployment

### Why This Approach?

1. **Pure NixOS**: Everything declarative, no container runtime needed
2. **Lighter Weight**: Native systemd services, no container overhead
3. **Better Integration**: Direct access to NixOS modules (sops, ACME, nginx)
4. **Easier Debugging**: Standard journalctl, no docker logs
5. **Reproducible**: Nix hash verification, pinned dependencies
6. **Rollback**: NixOS generations allow instant rollback

### Comparison

| Aspect | This Module | Docker Compose |
|--------|-------------|----------------|
| **Runtime** | PHP-FPM (native) | php:apache container |
| **Database** | MariaDB (systemd) | mysql:8 container |
| **Secrets** | sops-nix | .env files or docker secrets |
| **SSL** | ACME (Let's Encrypt) | Manual or reverse proxy |
| **Backups** | System-level tools | Container volumes |
| **Updates** | `nixos-rebuild` | `docker-compose pull` |
| **Rollback** | Instant (NixOS generations) | Manual restore |

## Contributing

When modifying this module:

1. **Test the build**: Ensure `phpipam.nix` evaluates correctly
2. **Test deployment**: Deploy to a VM or test server
3. **Verify functionality**: Access web interface, test API
4. **Check logs**: Ensure no errors in systemd journals
5. **Test updates**: Verify version upgrades work cleanly

## References

- [phpIPAM Official Site](https://phpipam.net/)
- [phpIPAM GitHub](https://github.com/phpipam/phpipam)
- [phpIPAM Documentation](https://phpipam.net/documents/)
- [phpIPAM API Documentation](https://phpipam.net/api/api_documentation/)
- [NixOS Manual - PHP-FPM](https://nixos.org/manual/nixos/stable/index.html#module-services-phpfpm)
- [NixOS Manual - MySQL](https://nixos.org/manual/nixos/stable/index.html#module-services-mysql)
- [sops-nix Documentation](https://github.com/Mic92/sops-nix)

## License

This NixOS module wrapper is provided as-is for public use.

phpIPAM itself is licensed under GPL-3.0. See the [phpIPAM repository](https://github.com/phpipam/phpipam) for details.

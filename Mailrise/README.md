# Mailrise - NixOS Package & Module

This repository contains a Nix package and NixOS module for deploying [Mailrise](https://mailrise.xyz), an SMTP gateway that converts emails into Apprise notifications.

## What is Mailrise?

Mailrise is an SMTP server that forwards emails to 60+ notification services via [Apprise](https://github.com/caronc/apprise). It enables:

- **Linux servers** to send notifications without storing credentials
- **IoT devices** to access modern notification services
- **Legacy software** to send alerts via Pushover, Discord, Telegram, Matrix, etc.

**Example:** Send an email to `pushover@mailrise.xyz` → Pushover notification

**Key Features:**
- 60+ notification services (Pushover, Discord, Telegram, Matrix, Nextcloud, SMS, etc.)
- SMTP server (port 8025 by default)
- YAML configuration for notification routing
- Optional TLS/STARTTLS support
- Optional SMTP authentication
- Email attachments passthrough

## Usage in NixOS

### As a NixOS Service Module

This module creates a complete Mailrise deployment using:
- **Python 3.8+** with apprise, aiosmtpd, PyYAML
- **systemd service** for automatic startup
- **User isolation** (dedicated `mailrise` user)

Example usage:

```nix
# In your NixOS configuration
{ config, pkgs, ... }:

{
  imports = [
    /path/to/Mailrise/mailrise.nix
  ];

  services.mailrise = {
    enable = true;
    listenAddress = "0.0.0.0";  # Listen on all interfaces
    port = 8025;

    # Provide your custom configuration file
    configFile = /path/to/mailrise-config.yaml;
  };
}
```

### With Colmena (Multi-Host Deployment)

```nix
# homelab/hosts.nix
{
  your-server = [
    ./services/mailrise.nix
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
    /path/to/Mailrise/mailrise.nix
  ];

  services.mailrise = {
    enable = true;
    # ... configuration
  };
}
```

## Configuration

### Basic Configuration File

Create a YAML configuration file:

```yaml
# /etc/mailrise/config.yaml

configs:
  # Pushover notifications
  pushover:
    urls:
      - pover://USER_KEY@TOKEN

  # Discord webhook
  discord:
    urls:
      - discord://WEBHOOK_ID/WEBHOOK_TOKEN

  # Multiple services at once
  all:
    urls:
      - pover://USER_KEY@TOKEN
      - discord://WEBHOOK_ID/WEBHOOK_TOKEN
      - tgram://BOT_TOKEN/CHAT_ID

listen:
  host: 0.0.0.0
  port: 8025
```

### NixOS Module Options

```nix
services.mailrise = {
  enable = true;               # Enable the Mailrise service

  package = pkgs.mailrise;     # Override package if needed

  configFile = /path/to/config.yaml;  # Required: YAML config file

  listenAddress = "127.0.0.1"; # Default: localhost only
                               # Use "0.0.0.0" for all interfaces

  port = 8025;                 # Default SMTP port

  user = "mailrise";           # Service user (created automatically)
  group = "mailrise";          # Service group
};
```

### Configuration File Options

Full configuration syntax:

```yaml
configs:
  # Email address → notification config mapping
  # Send to: <config_name>@mailrise.xyz
  pushover:
    urls:
      - pover://USER_KEY@TOKEN
    # Optional: customize notification templates
    mailrise:
      title_template: "$subject ($from)"
      body_template: "$body"
      body_format: text  # text, html, or markdown

# Network settings
listen:
  host: 0.0.0.0
  port: 8025

# Optional: TLS encryption
tls:
  mode: starttls  # off, onconnect, starttls, starttlsrequire
  certfile: /path/to/cert.pem
  keyfile: /path/to/key.pem

# Optional: SMTP authentication
smtp:
  auth:
    basic:
      username: password
      admin: secretpass
```

## Deployment Instructions

### Step 1: Create Configuration

Create your Mailrise configuration file with notification targets:

```yaml
# /etc/mailrise/config.yaml
configs:
  alerts:
    urls:
      - pover://USER_KEY@TOKEN  # Replace with your Pushover credentials

listen:
  host: 0.0.0.0
  port: 8025
```

### Step 2: Enable Service

```nix
# In your NixOS configuration
services.mailrise = {
  enable = true;
  listenAddress = "0.0.0.0";
  port = 8025;
  configFile = /etc/mailrise/config.yaml;
};
```

### Step 3: Deploy

```bash
# Single host deployment
sudo nixos-rebuild switch

# Or with Colmena (multi-host)
colmena apply --on your-server
```

### Step 4: Test

Send a test email:

```bash
# Using swaks (SMTP test tool)
nix-shell -p swaks --run "swaks --to alerts@mailrise.xyz --server localhost:8025 --from test@example.com --header 'Subject: Test Alert' --body 'This is a test notification'"

# Or using Python
python3 << EOF
import smtplib
from email.message import EmailMessage

msg = EmailMessage()
msg.set_content('This is a test notification from Mailrise!')
msg['Subject'] = 'Test Alert'
msg['From'] = 'test@example.com'
msg['To'] = 'alerts@mailrise.xyz'

with smtplib.SMTP('localhost', 8025) as s:
    s.send_message(msg)
EOF
```

You should receive a notification via your configured service!

## Common Use Cases

### 1. Cron Job Notifications

```bash
# Crontab entry that emails on completion
0 2 * * * /path/to/backup.sh && echo "Backup completed" | mail -s "Backup Success" alerts@mailrise.xyz

# Or in a shell script
if backup_command; then
    echo "Backup successful" | mail -s "Backup Success" alerts.success@mailrise.xyz
else
    echo "Backup failed" | mail -s "Backup Failed" alerts.failure@mailrise.xyz
fi
```

### 2. Server Monitoring Alerts

Configure your monitoring tools to send emails:

```bash
# Uptime Kuma, Grafana, Prometheus Alertmanager, etc.
SMTP Server: your-server.local
SMTP Port: 8025
From: monitoring@yourserver.com
To: alerts@mailrise.xyz
```

### 3. Application Logs

```python
# Python logging with SMTP handler
import logging
import logging.handlers

smtp_handler = logging.handlers.SMTPHandler(
    mailhost=('localhost', 8025),
    fromaddr='app@yourserver.com',
    toaddrs=['alerts@mailrise.xyz'],
    subject='Application Error'
)
smtp_handler.setLevel(logging.ERROR)

logger = logging.getLogger()
logger.addHandler(smtp_handler)
```

### 4. Notification Types

Mailrise supports Apprise notification types via email address suffixes:

```bash
# Default (info): alerts@mailrise.xyz
# Success: alerts.success@mailrise.xyz
# Warning: alerts.warning@mailrise.xyz
# Failure: alerts.failure@mailrise.xyz
```

These change the notification color/icon on supported services.

## Apprise Services

Mailrise supports 60+ notification services via Apprise. Popular examples:

| Service | URL Format | Example |
|---------|------------|---------|
| **Pushover** | `pover://USER_KEY@TOKEN` | `pover://u123...@a456...` |
| **Discord** | `discord://WEBHOOK_ID/TOKEN` | `discord://123.../abc...` |
| **Telegram** | `tgram://BOT_TOKEN/CHAT_ID` | `tgram://123:ABC.../456` |
| **Matrix** | `matrix://USER:PASS@HOST/#ROOM` | `matrix://bot:pass@matrix.org/#alerts` |
| **Slack** | `slack://TOKEN_A/TOKEN_B/TOKEN_C` | `slack://T.../B.../X...` |
| **Email** | `mailto://USER:PASS@DOMAIN` | `mailto://user:pass@gmail.com` |
| **Nextcloud** | `ncloud://USER:PASS@HOST` | `ncloud://admin:pass@cloud.example.com` |
| **SMS (Twilio)** | `twilio://SID:TOKEN@FROM/TO` | `twilio://AC.../auth.../+1234/+5678` |

Full list: https://github.com/caronc/apprise/wiki

## Troubleshooting

### Service Won't Start

Check systemd status:

```bash
sudo systemctl status mailrise
sudo journalctl -u mailrise -f
```

Common issues:
- Invalid YAML in config file
- Missing Apprise URL credentials
- Port already in use (8025)

### Test SMTP Connection

```bash
# Check if Mailrise is listening
sudo ss -tlnp | grep 8025

# Test connection
telnet localhost 8025
# Should see: 220 <hostname> Mailrise SMTP gateway
```

### Configuration Validation

Test your YAML syntax:

```bash
nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml; yaml.safe_load(open(\"/path/to/config.yaml\"))'"
```

### Firewall Issues

If accessing from remote hosts:

```nix
# Open firewall port (automatic if listenAddress = "0.0.0.0")
networking.firewall.allowedTCPPorts = [ 8025 ];
```

Or manually:

```bash
sudo firewall-cmd --add-port=8025/tcp --permanent
sudo firewall-cmd --reload
```

## Security Considerations

### Network Exposure

- **Default**: Listens on `127.0.0.1` (localhost only)
- **LAN Access**: Set `listenAddress = "0.0.0.0"` and use firewall rules
- **Public Access**: Use TLS + authentication (see below)

### TLS Encryption

```yaml
tls:
  mode: starttls
  certfile: /var/lib/acme/example.com/cert.pem
  keyfile: /var/lib/acme/example.com/key.pem
```

Or use a reverse proxy (nginx, Traefik) for TLS termination.

### SMTP Authentication

```yaml
smtp:
  auth:
    basic:
      username: strongpassword
      admin: anotherstrongpass
```

### Secrets Management

Use sops-nix for sensitive configuration:

```nix
sops.secrets."mailrise/config" = {
  sopsFile = ./secrets.yaml;
  owner = "mailrise";
  group = "mailrise";
};

services.mailrise.configFile = config.sops.secrets."mailrise/config".path;
```

## Advanced: Custom Templates

Customize notification format:

```yaml
configs:
  custom:
    urls:
      - pover://USER_KEY@TOKEN
    mailrise:
      title_template: "[${type}] ${subject}"
      body_template: |
        From: ${from}
        To: ${to}

        ${body}
      body_format: markdown
```

Template variables:
- `$subject`: Email subject
- `$from`: Sender address
- `$to`: Recipient address
- `$body`: Email body
- `$config`: Config name
- `$type`: Notification type (info/success/warning/failure)

## References

- [Mailrise Official Site](https://mailrise.xyz)
- [Mailrise GitHub](https://github.com/YoRyan/mailrise)
- [Apprise Documentation](https://github.com/caronc/apprise/wiki)
- [Apprise Service List](https://github.com/caronc/apprise/wiki#notification-services)

## License

This NixOS module and package wrapper is provided as-is for public use.

Mailrise itself is licensed under MIT. See the [Mailrise repository](https://github.com/YoRyan/mailrise) for details.

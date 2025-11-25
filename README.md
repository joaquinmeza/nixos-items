# NixOS Items

A collection of standalone NixOS packages and configurations.

## Overview

This repository contains individual NixOS items (packages, derivations, and configurations) that can be used independently. These are **not** a complete NixOS system configuration - they're modular components you can integrate into your own setup.

My full NixOS configuration is not yet public as I'm still sanitizing it for private information. This repository serves as a place to share useful standalone items that others might find helpful.

## Contents

- **[Google-Antigravity](./Google-Antigravity/)** - Nix package for Google's Antigravity agentic development platform
- **[Mailrise](./Mailrise/)** - Nix package + NixOS service module for Mailrise (SMTP → Apprise notifications gateway)
- **[phpIPAM](./phpIPAM/)** - NixOS service module for phpIPAM (IP address management) using native PHP-FPM + MySQL

Each item has its own README with usage instructions and details.

## Usage

Each directory contains a self-contained item that can be:

- Called directly with `pkgs.callPackage`
- Integrated into your NixOS configuration
- Used in Home Manager setups
- Referenced as a flake input

See individual item READMEs for specific usage examples.

## License

Each item may have its own license. Check the individual directories for details.

## Contributing

Feel free to open issues or submit pull requests if you find bugs or have improvements to suggest.

# Google Antigravity - Nix Package

This repository contains a Nix derivation for packaging Google's Antigravity desktop client.

## What is Antigravity?

Antigravity is Google's experimental agentic development platform that combines an AI-centric IDE with autonomous coding agents. Built on top of Project IDX infrastructure, Antigravity represents Google's vision for "agent-first" software development.

**Key Features:**
- **Multi-Model Support**: Powered by Gemini 3 Pro, with support for Anthropic's Claude Sonnet 4.5 and OpenAI's GPT-OSS models
- **Agentic Coding**: AI agents that can autonomously complete development tasks
- **Agent Manager**: Mission Control surface for spawning, orchestrating, and observing multiple agents working asynchronously
- **Artifact System**: Agents produce verifiable deliverables (task lists, plans, screenshots, browser recordings) for trust and validation
- **Interactive Feedback**: Provide Google Docs-style comments on agent work to guide and improve results
- **Adaptive Learning**: Agents maintain internal knowledge bases from previous successful tasks

Antigravity is currently available for free in public preview with generous rate limits for Gemini 3 Pro usage.

## Usage in NixOS/Home Manager

### As a Home Manager Package

This derivation is designed to be consumed by Home Manager configurations. Example usage:

```nix
# In your home-manager configuration (e.g., ~/NixSetups/home/desktop/mango/config.nix)
{ config, pkgs, ... }:

let
  antigravity = pkgs.callPackage /path/to/Google-Antigravity/antigravity.nix {};
in
{
  home.packages = [
    antigravity
  ];
}
```

### As a NixOS System Package

```nix
# In your NixOS configuration.nix
{ config, pkgs, ... }:

let
  antigravity = pkgs.callPackage /path/to/Google-Antigravity/antigravity.nix {};
in
{
  environment.systemPackages = [
    antigravity
  ];
}
```

### Using Flakes

If you're using Nix flakes, you can reference this as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    antigravity.url = "path:/path/to/Google-Antigravity";
  };

  outputs = { self, nixpkgs, antigravity, ... }: {
    # Your configuration here
  };
}
```

## How It Works

### Download and Installation

The derivation automatically:

1. **Downloads** the official Antigravity tarball from Google's servers
   - URL: `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz`
   - Version: `1.11.2-6251250307170304`
   - SHA256: Verified hash for reproducibility

2. **Patches binaries** using `autoPatchelfHook`
   - Automatically fixes ELF binary dependencies
   - Links required system libraries

3. **Bundles dependencies**
   - Includes all necessary Electron/Chromium libraries
   - Standard library dependencies (glibc, etc.)
   - X11 and Wayland support libraries
   - Audio, graphics, and system integration libraries

4. **Creates wrapper script**
   - Sets up `LD_LIBRARY_PATH` for runtime dependencies
   - Enables Wayland support when available
   - Adds `--no-sandbox` flag (see Security Considerations)

5. **Installs desktop integration**
   - Desktop file for application menus
   - Icon integration
   - MIME type handler for `x-scheme-handler/idx` URLs

### File Structure

After installation:
```
$out/
├── bin/
│   └── antigravity              # Wrapper script (main executable)
├── lib/antigravity/             # Complete application bundle
│   ├── antigravity              # Actual binary
│   ├── chrome-sandbox
│   ├── resources/
│   └── ...
└── share/
    ├── applications/
    │   └── antigravity.desktop
    └── pixmaps/
        └── antigravity.png
```

## Security Considerations

### Chrome Sandbox

The package runs with `--no-sandbox` flag because:
- Chrome's sandbox requires `setuid` permissions on `chrome-sandbox`
- Nix build environment cannot set `setuid` bits
- Running without sandbox is acceptable for most desktop use cases

**For enhanced security**, you can manually configure the system-wide wrapper:
```bash
sudo chown root:root /nix/store/*/lib/antigravity/chrome-sandbox
sudo chmod 4755 /nix/store/*/lib/antigravity/chrome-sandbox
```

Note: This must be done after each update and may not persist across garbage collection.

## Updating the Version

To update to a new version:

1. **Find the new version number** from Google's download page
2. **Update the version** in `antigravity.nix`:
   ```nix
   version = "NEW_VERSION_HERE";
   ```
3. **Update the SHA256 hash**:
   ```bash
   # Set hash to empty string first
   sha256 = "";

   # Try to build - Nix will show the expected hash
   nix-build antigravity.nix

   # Or use nix-prefetch-url
   nix-prefetch-url https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/NEW_VERSION/linux-x64/Antigravity.tar.gz
   ```

## Troubleshooting

### Application won't start

1. Check if all dependencies are available:
   ```bash
   ldd $(which antigravity)
   ```

2. Run with verbose output:
   ```bash
   antigravity --verbose
   ```

### Missing icon

The icon is extracted from the tarball. If missing, the package falls back to a default terminal icon. You can manually specify an icon by modifying the desktop file.

### Wayland issues

The wrapper automatically enables Wayland support when `WAYLAND_DISPLAY` and `NIXOS_OZONE_WL` are set. To force X11:
```bash
unset NIXOS_OZONE_WL
antigravity
```

## Platform Support

- **Supported**: `x86_64-linux` only
- **License**: Unfree (Google proprietary software)

Make sure your Nix configuration allows unfree packages:
```nix
nixpkgs.config.allowUnfree = true;
```

## Contributing

When updating or modifying this derivation:

1. Test the build: `nix-build antigravity.nix`
2. Test the application: `./result/bin/antigravity`
3. Verify desktop integration works
4. Check that dependencies are correctly linked

## References

- [Google Antigravity Homepage](https://antigravity.google)
- [Antigravity Documentation](https://antigravity.google/docs/get-started)
- [Project IDX](https://idx.dev) (the underlying infrastructure)
- [The New Stack: Antigravity Launch Article](https://thenewstack.io/antigravity-is-googles-new-agentic-development-platform/)
- [NixOS Manual - Packaging](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
- [autoPatchelfHook Documentation](https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook)

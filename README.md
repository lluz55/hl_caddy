# HL-Caddy

A NixOS configuration for a Caddy server integrated with a zrok tunnel.

## Description

This project provides a NixOS module that sets up a local-only Caddy reverse proxy and exposes it externally through a zrok tunnel. It allows you to expose local services through Caddy and use zrok as an external entry point, supporting environment variables via a `.env` file.

## Usage

To use this module in your own NixOS configuration, integrate it into your system's `flake.nix` and use an `.env` file in the current directory to configure an app named `hat`.

### 1. System `flake.nix` Structure

Add this repository as an input to your `flake.nix` and import the exported module into your system configuration:

```nix
{
  description = "My NixOS System Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Add the reference to the hl_caddy repository
    # Replace with the actual URL/path of the repository (e.g., git+https://github.com/user/hl_caddy.git or local path)
    hl-caddy.url = "github:lluz55/hl-caddy"; 
    hl-caddy.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, hl-caddy, ... }@inputs: {
    nixosConfigurations = {
      my-system = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Import the module provided by hl_caddy
          hl-caddy.nixosModules.default
          
          # Your hardware and base configuration
          # ./hardware-configuration.nix
          
          # hl-caddy configuration
          ({ config, pkgs, ... }: {
            services.hl-caddy = {
              enable = true;
              
              # zrok configuration
              zrok = {
                enable = true;
                # Points to the .env file in the current directory of your flake.
                # Warning: Avoid using `${./.env}` if the file contains secrets (like ZROK_TOKEN),
                # as this copies the file to the Nix Store in a readable format.
                # The ideal way is to use the absolute path as a string.
                environmentFile = "/absolute/path/to/the/current/directory/.env"; 
              };

              # Definition of the "hat" app
              services.hat = {
                path = "/hat/";             # Path that Caddy will use to listen for the app
                proxyTo = "localhost:8080"; # Local port where the real 'hat' app is running
              };
            };
          })
        ];
      };
    };
  };
}
```

### 2. The `.env` file

In the directory specified in the `environmentFile` option, you will need a `.env` file containing the vital zrok configurations for the tunnel to work:

```env
# Token obtained from https://zrok.io/
ZROK_TOKEN=your_token_here
TUNNEL_ZROK_MODE=public
TUNNEL_ZROK_TARGET=http://127.0.0.1:80
TUNNEL_ZROK_PUBLIC_BASE=shares.zrok.io
TUNNEL_ZROK_INSTANCE_NAME=my-instance
```

### How this integration works under the hood:
1. **The Module:** When enabled (`services.hl-caddy.enable = true`), it automatically starts and configures a Caddy service and a systemd service for zrok (`zrok-tunnel`).
2. **The 'hat' App:** The module dynamically configures Caddy to intercept all requests on the path `/hat/*` and performs a `reverse_proxy` to `localhost:8080` (where your real 'hat' app should be running).
3. **The `.env`:** The systemd service will read this `.env` on startup (`EnvironmentFile`). If the environment is not yet authenticated on zrok, a pre-start script will use the `ZROK_TOKEN` contained in the `.env` file to authenticate the machine before exposing the services headlessly.

## Features

- **Caddy Reverse Proxy:** Easily configure multiple backend services.
- **zrok as External Ingress:** Public access happens through zrok.
- **Tunnel via `.env` or Nix options:** Runtime env vars can override flake defaults.
- **NixOS Module:** Purely functional and reproducible configuration.

## Getting Started

### Prerequisites

- A NixOS system with Flakes enabled.
- A [zrok](https://zrok.io/) account and token.

### Configuration

1. Copy `.env.example` to `.env` and fill in your `ZROK_TOKEN`.
   ```bash
   cp .env.example .env
   ```
2. Include the module in your NixOS configuration.

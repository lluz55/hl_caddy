# HL-Caddy

A NixOS configuration for a Caddy server integrated with a zrok tunnel.

## Description

This project provides a NixOS module that sets up a local-only Caddy reverse proxy and exposes it externally through a zrok tunnel.

## Usage

To use this module in your own NixOS configuration, add this repository as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hl-caddy.url = "github:lluz55/hl-caddy"; # Replace with actual URL
  };

  outputs = { self, nixpkgs, hl-caddy }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        hl-caddy.nixosModules.default
        ({ config, pkgs, ... }: {
          services.hl-caddy = {
            enable = true;
            listenAddress = "127.0.0.1";
            listenPort = 80;
            zrok = {
              # Option 1: Using an environment file (like .env)
              environmentFile = "/etc/nixos/secrets/zrok.env";
              
              # Option 2: Configuring directly via Nix options
              # tokenFile = pkgs.writeText "zrok-token" "your-token-here";
              # mode = "public";
              # target = "http://127.0.0.1:80";
              # extraArgs = [ "--headless" ];
              # publicBase = "shares.zrok.io";
              # instanceName = "my-custom-name";
            };
            services = {
              app = {
                path = "/app/";
                proxyTo = "localhost:8080";
              };
            };
          };
        })
      ];
    };
  };
}
```

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

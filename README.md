# HL-Caddy

A NixOS configuration for a Caddy server integrated with a zrok tunnel.

## Description

This project provides a NixOS module that sets up a Caddy server to act as a reverse proxy, combined with a zrok tunnel to expose local services securely.

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
            domain = "my-site.example.com";
            zrok = {
              enable = true;
              # Path to your .env file containing ZROK_TOKEN
              environmentFile = "/etc/nixos/secrets/zrok.env";
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
- **zrok Tunnel:** Automated integration for exposing services.
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

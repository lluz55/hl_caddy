# HL-Caddy

A NixOS configuration for a Caddy server integrated with a zrok tunnel.

## Description

This project provides a NixOS module that sets up a Caddy server to act as a reverse proxy, combined with a zrok tunnel to expose local services securely.

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

{
  description = "A NixOS module for Caddy with a zrok tunnel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = { config, lib, pkgs, ... }:
      let
        cfg = config.services.hl-caddy;
      in
      {
        options.services.hl-caddy = {
          enable = lib.mkEnableOption "HL-Caddy services";

          listenAddress = lib.mkOption {
            type = lib.types.str;
            description = "Internal bind address for Caddy. Keep this local so zrok is the external entrypoint.";
            default = "127.0.0.1";
          };

          listenPort = lib.mkOption {
            type = lib.types.port;
            description = "Internal Caddy port used by the zrok tunnel target.";
            default = 80;
          };

          services = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "The URL path for this service (e.g., /hat/).";
                };
                proxyTo = lib.mkOption {
                  type = lib.types.str;
                  description = "The local address and port to proxy to (e.g., localhost:20001).";
                };
              };
            });
            default = {
              hat = {
                path = "/hat/";
                proxyTo = "localhost:20001";
              };
            };
            description = "Map of services to be registered in Caddy.";
          };

          zrok = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable zrok tunnel. This module expects zrok as the external ingress.";
            };
            
            tokenFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to a file containing the zrok environment token.";
            };

            environmentFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to an environment file (.env) for zrok configuration.";
            };

            mode = lib.mkOption {
              type = lib.types.enum [ "public" "private" ];
              default = "public";
              description = "zrok share mode.";
            };

            target = lib.mkOption {
              type = lib.types.str;
              default = "http://127.0.0.1:80";
              description = "Tunnel target address, usually the local Caddy listener.";
            };

            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "--headless" ];
              description = "Extra arguments passed to 'zrok share'.";
            };

            publicBase = lib.mkOption {
              type = lib.types.str;
              default = "shares.zrok.io";
              description = "The public base domain for zrok shares.";
            };

            instanceName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The instance name for the zrok share (prefixed to publicBase).";
            };
          };
        };

        config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.zrok.enable;
              message = "services.hl-caddy requires services.hl-caddy.zrok.enable = true because zrok is the external ingress.";
            }
          ];

          # Enable Caddy
          services.caddy = {
            enable = true;
            # Caddy stays internal-only; zrok is the public entrypoint.
            virtualHosts."http://${cfg.listenAddress}:${toString cfg.listenPort}".extraConfig = (
              lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: service: 
                  let 
                    upperName = lib.toUpper name;
                  in ''
                  handle_path {env.SERVICE_${upperName}_PATH}* {
                    reverse_proxy {env.SERVICE_${upperName}_PROXY}
                  }
                '') cfg.services
              )
            );
          };

          # Para que o Caddy enxergue as variáveis do .env, precisamos passá-las
          systemd.services.caddy = {
            serviceConfig.EnvironmentFile = lib.optional (cfg.zrok.environmentFile != null) cfg.zrok.environmentFile;
            # Valores padrão caso não estejam no .env
            environment = lib.mapAttrs' (name: service: 
              lib.nameValuePair "SERVICE_${lib.toUpper name}_PATH" service.path
            ) cfg.services // lib.mapAttrs' (name: service:
              lib.nameValuePair "SERVICE_${lib.toUpper name}_PROXY" service.proxyTo
            ) cfg.services;
          };

          # Zrok Service Configuration
          systemd.services.zrok-tunnel = {
            description = "zrok tunnel service";
            after = [ "network-online.target" "caddy.service" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            environment = {
              ZROK_HOME = "/var/lib/zrok";
              TUNNEL_ZROK_PUBLIC_BASE = cfg.zrok.publicBase;
            } // (lib.optionalAttrs (cfg.zrok.instanceName != null) {
              TUNNEL_ZROK_INSTANCE_NAME = cfg.zrok.instanceName;
            });

            serviceConfig = {
              Type = "simple";
              User = "caddy";
              StateDirectory = "zrok";
              EnvironmentFile = lib.optional (cfg.zrok.environmentFile != null) cfg.zrok.environmentFile;
              
              # Auto-enable if token is available
              ExecStartPre = pkgs.writeShellScript "zrok-init" ''
                if [ ! -f /var/lib/zrok/environment.json ]; then
                  export TUNNEL_ZROK_PUBLIC_BASE="''${TUNNEL_ZROK_PUBLIC_BASE:-${cfg.zrok.publicBase}}"
                  
                  TOKEN=""
                  ${lib.optionalString (cfg.zrok.tokenFile != null) ''
                  if [ -f "${cfg.zrok.tokenFile}" ]; then
                    TOKEN=$(cat "${cfg.zrok.tokenFile}")
                  fi
                  ''}
                  if [ -z "$TOKEN" ] && [ -n "$ZROK_TOKEN" ]; then
                    TOKEN="$ZROK_TOKEN"
                  fi

                  if [ -n "$TOKEN" ]; then
                    ${pkgs.zrok}/bin/zrok enable "$TOKEN" --headless
                  else
                    echo "No zrok token found in tokenFile or ZROK_TOKEN env var. Skipping enable."
                  fi
                fi
              '';

              ExecStart = pkgs.writeShellScript "zrok-start" ''
                SHARE_MODE="''${TUNNEL_ZROK_MODE:-${cfg.zrok.mode}}"
                SHARE_TARGET="''${TUNNEL_ZROK_TARGET:-${cfg.zrok.target}}"
                EXTRA_ARGS="${lib.escapeShellArgs cfg.zrok.extraArgs}"

                if [ -n "$TUNNEL_ZROK_EXTRA_ARGS" ]; then
                  EXTRA_ARGS="$TUNNEL_ZROK_EXTRA_ARGS"
                fi

                if [ -n "$TUNNEL_ZROK_INSTANCE_NAME" ] && [[ "$EXTRA_ARGS" != *"--name"* ]]; then
                  EXTRA_ARGS="$EXTRA_ARGS --name $TUNNEL_ZROK_INSTANCE_NAME"
                fi

                # shellcheck disable=SC2086
                exec ${pkgs.zrok}/bin/zrok share "$SHARE_MODE" "$SHARE_TARGET" $EXTRA_ARGS
              '';
              Restart = "on-failure";
              RestartSec = "10s";
            };
          };

          # Ensure zrok is in the system path for convenience
          environment.systemPackages = [ pkgs.zrok ];
        };
      };
  };
}

{
  lineage,
  config,
  pkgs-stable,
  pkgs,
  lib,
  ...
}:

let
  domain = "jameshollister.org";
  tailnet = "seagull-court.ts.net";
in
{
  # Fixes a bug in nginx virtualHosts where they dont use the default acme setup
  # Reference: https://github.com/NixOS/nixpkgs/issues/210807#issuecomment-1383263210
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.acmeRoot = lib.mkDefault null;
      }
    );
  };

  config = lib.mkMerge [

    # Ensures server hosting laptops dont sleep when closing the lid and screen turns off quickly
    (lib.mkIf (!(lineage.has.usage "Desktop") && (lineage.has.form "Laptop")) {
      services.logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };

      boot.kernelParams = [ "consoleblank=30" ];
    })

    (lib.mkIf (lineage.has.usage "Nix Remote Builder") {

      # Creates a user for nix remote builds to run under
      users.users.nix-builder = {
        isNormalUser = true;
        description = "Nix remote builder";
      };

      nix = {
        distributedBuilds = lib.mkForce false; # Prevents cyclical remote builds
        settings.trusted-users = [ "nix-builder" ]; # Allows nix-builder to build things
      };
    })

    # Nginx support (Really just my main reverse proxy, cert signing and dns setup)
    (lib.mkIf (lineage.has.usage "Nginx") {
      services = {
        nginx = {
          enable = true;
          recommendedTlsSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
        };

        # Sets cloudflare DNS for my hosted projects
        cloudflare-cname = {
          enable = true;
          zone = domain;
          tokenFile = config.sops.secrets.CLOUDFLARE_DNS_API_TOKEN.path;
        };
      };

      # Signs certs
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "me@${domain}";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.templates."acme-env".path;
        };

        certs.${domain}.domain = "*.${domain}";
      };

      environment.persistence."/nix/persist".directories = [ "/var/lib/acme" ];
    })

    # Caddy support
    (lib.mkIf (lineage.has.usage "Caddy") {
      services = {
        tailscale.permitCertUid = "caddy";
        caddy.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    })

    # Traefik Support
    (lib.mkIf (lineage.has.usage "Traefik") {
      services.traefik.enable = true;
    })

    (lib.mkIf (lineage.has.usage "Monitoring") {
      services =
        let
          grafana = {
            http_port = 3001;
            subdomain = "monitoring";
            domain = "${grafana.subdomain}.${domain}";
          };
          loki = {
            port = 3100;
            subdomain = "loki";
            domain = "${loki.subdomain}.${domain}";
          };
          prometheus = {
            port = 9090;
            subdomain = "prometheus";
            domain = "${prometheus.subdomain}.${domain}";
          };
        in
        {
          # Monitors all active systems
          prometheus = {
            enable = true;
            inherit (prometheus) port;
            retentionTime = "90d";
            extraFlags = [ "--web.enable-remote-write-receiver" ];

            exporters.blackbox = {
              enable = true;
              openFirewall = false;
              configFile = pkgs.writeText "blackbox.yml" ''
                modules:
                  http_2xx:
                    prober: http
                    timeout: 10s
                    http:
                      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
                      valid_status_codes: [200, 301, 302]
                      follow_redirects: true
                      preferred_ip_protocol: "ip4"
              '';
            };

            scrapeConfigs = [
              {
                job_name = "services";
                metrics_path = "/probe";
                params = {
                  module = [ "http_2xx" ];
                };
                static_configs = [
                  {
                    targets = [
                      "https://git.${domain}"
                      "https://cloud.${domain}"
                      "https://n8n.${domain}"
                      "https://${grafana.domain}"
                    ];
                  }
                ];
                relabel_configs = [
                  {
                    source_labels = [ "__address__" ];
                    target_label = "__param_target";
                  }
                  {
                    source_labels = [ "__param_target" ];
                    target_label = "instance";
                  }
                  {
                    target_label = "__address__";
                    replacement = "127.0.0.1:9115";
                  }
                ];
              }
            ];
          };

          # Loki for log management
          loki = {
            enable = true;
            configuration = {
              auth_enabled = false;
              server.http_listen_port = loki.port;
              limits_config.retention_period = "744h";
              schema_config.configs = [
                {
                  from = "2024-01-01";
                  store = "tsdb";
                  object_store = "filesystem";
                  schema = "v13";
                  index = {
                    prefix = "index_";
                    period = "24h";
                  };
                }
              ];
              common = {
                ring = {
                  instance_addr = "127.0.0.1";
                  kvstore.store = "inmemory";
                };
                replication_factor = 1;
                path_prefix = "/var/lib/loki";
              };
              storage_config = {
                tsdb_shipper = {
                  active_index_directory = "/var/lib/loki/tsdb-index";
                  cache_location = "/var/lib/loki/tsdb-cache";
                };
                filesystem.directory = "/var/lib/loki/chunks";
              };
              compactor = {
                working_directory = "/var/lib/loki/compactor";
                retention_enabled = true;
                delete_request_store = "filesystem";
              };
            };
          };

          # WebUI to access prometheus & loki
          grafana = {
            enable = true;
            package = pkgs-stable.grafana;
            openFirewall = false;
            settings = {
              server = {
                http_addr = "127.0.0.1";
                inherit (grafana) domain http_port;
              };
              security = {
                admin_user = "admin";
                admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
                secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
              };
            };

            provision = {
              enable = true;
              datasources.settings.datasources = [
                {
                  name = "Prometheus";
                  type = "prometheus";
                  url = "http://127.0.0.1:${toString prometheus.port}";
                  isDefault = false;
                }
                {
                  name = "Loki";
                  type = "loki";
                  url = "http://127.0.0.1:${toString loki.port}";
                  isDefault = false;
                }
              ];
            };
          };

          # Nginx reverse proxy for Grafana & loki
          cloudflare-cname.records = {
            ${grafana.subdomain} = "${config.networking.hostName}.${tailnet}";
            ${prometheus.subdomain} = "${config.networking.hostName}.${tailnet}";
            ${loki.subdomain} = "${config.networking.hostName}.${tailnet}";
          };
          nginx.virtualHosts = {
            ${grafana.domain} = {
              forceSSL = true;
              enableACME = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:${toString grafana.http_port}";
                proxyWebsockets = true;
              };
            };
            ${prometheus.domain} = {
              forceSSL = true;
              enableACME = true;
              locations."/".proxyPass = "http://127.0.0.1:${toString prometheus.port}";
            };
            ${loki.domain} = {
              forceSSL = true;
              enableACME = true;
              locations."/".proxyPass = "http://127.0.0.1:${toString loki.port}";
            };
          };
        };

      # Persists the prometheus and grafana setup with proper ownership
      systemd.tmpfiles.rules = [
        "d ${config.services.grafana.dataDir} 0750 grafana grafana -"
        "d ${config.services.loki.dataDir} 0750 ${config.services.loki.user} ${config.services.loki.group} -"
      ];
      environment.persistence."/nix/persist".directories = [
        "/var/lib/${config.services.prometheus.stateDir}"
        config.services.grafana.dataDir
        config.services.loki.dataDir
      ];
    })

    # Setups up Forgejo, a self-hosted git server
    (lib.mkIf (lineage.has.usage "Forgejo") {
      services =
        let
          SSH_PORT = 2222;
          HTTP_PORT = 3000;
          SUBDOMAIN = "git";
          DOMAIN = "${SUBDOMAIN}.${domain}";
        in
        {
          cloudflare-cname.records.${SUBDOMAIN} = "${config.networking.hostName}.${tailnet}";
          openssh.ports = [ SSH_PORT ]; # Uses the system ssh installation on a different port
          nginx.virtualHosts.${DOMAIN} = {
            enableACME = true;
            forceSSL = true;
            extraConfig = "client_max_body_size 256m;";
            locations."/".proxyPass = "http://127.0.0.1:${toString HTTP_PORT}";
          };
          forgejo = {
            enable = true;
            package = pkgs.forgejo;
            database.type = "sqlite3";
            lfs.enable = true;
            settings = {
              actions = {
                ENABLED = true;
                DEFAULT_ACTIONS_URL = "github";
              };
              server = {
                inherit DOMAIN HTTP_PORT SSH_PORT;
                ROOT_URL = "https://${DOMAIN}";
                DISABLE_SSH = false;
                BUILTIN_SSH_SERVER = false;
              };
              session = {
                COOKIE_SECURE = true;
                SESSION_LIFE_TIME = 7776000; # 90 days in seconds
              };
            };
          };
        };

      # Persists forgejo
      environment.persistence."/nix/persist".directories = [ config.services.forgejo.stateDir ];

      # Ensures proper ownership for forgejo
      systemd.tmpfiles.rules = [
        "d /nix/persist${config.services.forgejo.stateDir} 0750 forgejo forgejo -"
      ];
    })

    (lib.mkIf (lineage.has.usage "Nextcloud") {
      services =
        let
          subdomain = "cloud";
        in
        {
          cloudflare-cname.records.${subdomain} = "${config.networking.hostName}.${tailnet}";
          nginx.virtualHosts.${config.services.nextcloud.hostName} = {
            forceSSL = true;
            enableACME = true;
          };
          nextcloud = {
            enable = true;
            configureRedis = true;
            appstoreEnable = true;
            autoUpdateApps.enable = true;
            package = pkgs.nextcloud33;
            hostName = "${subdomain}.${domain}";
            https = true;
            config = {
              adminuser = "admin";
              adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
              dbtype = "sqlite";
            };
          };
        };

      # Persist with proper ownership
      environment.persistence."/nix/persist".directories = [ config.services.nextcloud.datadir ];
      systemd.tmpfiles.rules = [
        "d /nix/persist${config.services.nextcloud.datadir} 0750 nextcloud nextcloud -"
      ];
    })

    # Setups n8n, a self-hosted workflow automation tool
    (lib.mkIf (lineage.has.usage "n8n") {
      services =
        let
          port = "5678";
          subdomain = "n8n";
        in
        {
          cloudflare-cname.records.${subdomain} = "${config.networking.hostName}.${tailnet}";
          nginx.virtualHosts."${subdomain}.${domain}" = {
            enableACME = true;
            forceSSL = true;
            extraConfig = "client_max_body_size 16m;";
            locations."/".proxyPass = "http://localhost:${port}";
          };
          n8n = {
            enable = true;
            openFirewall = false;
            package = pkgs.n8n;
            environment.N8N_PORT = port;
          };
        };

      # Needed for persistence with n8n, otherwise it fails
      systemd.services.n8n.serviceConfig.DynamicUser = lib.mkForce false;

      environment.persistence."/nix/persist".directories = [
        config.services.n8n.environment.N8N_USER_FOLDER
      ];
    })

    # Setup OpenClaw AI Agent
    (lib.mkIf (lineage.has.usage "OpenClaw") {

      # Creates the user and group
      users = {
        users.openclaw = {

          # Temporary solution until upstream is more stable
          isNormalUser = true;
          group = "wheel";

          # isSystemUser = true;
          home = "/var/lib/openclaw";
          createHome = true;
          description = "OpenClaw service user";
          linger = true;
        };
        groups.openclaw = { };
      };

      # Persist the installation and adds the package
      environment = {
        systemPackages = [ pkgs.openclaw ];
        persistence."/nix/persist".directories = [ config.users.users.openclaw.home ];
      };
    })

    (lib.mkIf (lineage.has.usage "Ollama") {
      services.ollama = {
        enable = true;
        openFirewall = true;
        package = pkgs.ollama-cuda; # Conditional logic here for later Ollamas
        user = "ollama"; # Needed for persistence
        host = "0.0.0.0";
        environmentVariables.num_batch = "512";
        loadModels = [
          "qwen3.5:0.8b"
          "qwen3.5:4b"
          "qwen3.5:9b"
        ];
      };

      # Persist Ollama with the proper permissions
      environment.persistence."/nix/persist".directories = [ "/var/lib/private" ];
      systemd.tmpfiles.rules = [ "d /var/lib/private/ollama 0700 ollama ollama -" ];
    })

    # Hosts a game server panel manager
    (lib.mkIf (lineage.has.usage "PufferPanel") (
      let
        port = "8080";
        subdomain = "gaming";
      in
      {

        services = {

          # UI for managing game servers
          pufferpanel = {
            enable = true;
            package = pkgs.buildFHSEnv {
              name = "pufferpanel-fhs";
              runScript = lib.getExe pkgs.pufferpanel;
            };
            environment = {
              PUFFER_WEB_HOST = ":${port}";
              PUFFER_PANEL_ENABLE = "true";
              PUFFER_PANEL_REGISTRATIONENABLED = "false";
            };
          };

          cloudflare-cname.records.${subdomain} = "${config.networking.hostName}.${tailnet}";
          nginx.virtualHosts."${subdomain}.${domain}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${port}";
              proxyWebsockets = true;
            };
          };
        };

        # Creates a user for pufferpanel
        users.users.pufferpanel = {
          isSystemUser = true;
          group = "pufferpanel";
          home = "/var/lib/pufferpanel";
          createHome = true;
        };
        users.groups.pufferpanel = { };

        # Fixes issue with `DynamicUser` and persistence
        systemd.services.pufferpanel.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = lib.mkForce "pufferpanel";
          Group = lib.mkForce "pufferpanel";
        };

        # Persist path
        environment.persistence."/nix/persist".directories = [
          {
            directory = "/var/lib/pufferpanel";
            user = "pufferpanel";
            group = "pufferpanel";
            mode = "0750";
          }
        ];
      }
    ))

    # Opens firewall for Minecraft Server
    (lib.mkIf (lineage.has.usage "Minecraft Server") {
      networking.firewall = {
        allowedTCPPorts = [ 25565 ];
        allowedUDPPorts = [ 19132 ];
      };

      environment.systemPackages = with pkgs; [
        mrpack-install
        packwiz
      ];
    })

    # Easily allows connection to MC Servers from consoles
    (lib.mkIf (lineage.has.usage "MCXboxBroadcast") { services.mcxboxbroadcast.enable = true; })

    # Unbound is a Custom DNS resolver
    # These rules route the default minecraft bedrock servers to the server itself
    # I keep this around because Unbound is useful and having a template reduces boilerplate if I ever need it
    (lib.mkIf (lineage.has.usage "Unbound") {
      services.unbound = {
        enable = true;

        settings = {
          server = {
            "interface" = [
              "0.0.0.0"
              "127.0.0.1"
            ];
            "access-control" = [
              "0.0.0.0/0 allow"
            ];
            qname-minimisation = true;
            hide-identity = true;
            hide-version = true;
            do-ip4 = true;
            do-tcp = true;
            do-udp = true;
          };

          forward-zone = [
            {
              name = "play.inpvp.net";
              forward-addr = [ "127.0.0.1" ];
            }
            {
              name = "mco.lbsg.net";
              forward-addr = [ "127.0.0.1" ];
            }
            {
              name = "mco.cubecraft.net";
              forward-addr = [ "127.0.0.1" ];
            }
            {
              name = "geo.hivebedrock.network";
              forward-addr = [ "127.0.0.1" ];
            }
            {
              name = "play.galaxite.net";
              forward-addr = [ "127.0.0.1" ];
            }
            {
              name = "play.enchanted.gg";
              forward-addr = [ "127.0.0.1" ];
            }

            {
              name = ".";
              forward-addr = [
                "1.1.1.1"
                "1.0.0.1"
                "9.9.9.9"
                "149.112.112.112"
              ];
            }
          ];
        };
      };

      networking.firewall.allowedTCPPorts = [ 53 ];
      networking.firewall.allowedUDPPorts = [ 53 ];
    })

    # Installs Wake on Lan
    # Later I am going to setup an automated service using this
    # It will wake high powered systems on demand, when low powered ones request it
    (lib.mkIf (lineage.has.usage "Wake on Lan") {
      environment.systemPackages = [ pkgs.wakeonlan ];
    })
  ];
}

{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  domain = "jameshollister.org";
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

    # Nginx support
    (lib.mkIf (lineage.has.usage "Nginx") {
      services.nginx = {
        enable = true;
        recommendedTlsSettings = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "me@jameshollister.org";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.templates."acme-env".path;
        };

        certs.${domain} = {
          domain = "*.${domain}";
        };
      };

      environment.persistence."/nix/persist".directories = [
        "/var/lib/acme"
      ];
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

    # Setups up Forgejo, a self-hosted git server
    (lib.mkIf (lineage.has.usage "Forgejo") {
      services =
        let
          SSH_PORT = 2222;
          HTTP_PORT = 3000;
          DOMAIN = "git.${domain}";
        in
        {
          openssh.ports = [ SSH_PORT ]; # Uses the system ssh installation on a different port
          nginx.virtualHosts.${DOMAIN} = {
            enableACME = true;
            forceSSL = true;
            extraConfig = "client_max_body_size 256m;";
            locations."/".proxyPass = "http://localhost:${toString HTTP_PORT}";
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
      environment.persistence."/nix/persist".directories = [
        config.services.forgejo.stateDir
      ];

      # Ensures proper ownership for forgejo
      systemd.tmpfiles.rules = [
        "d /nix/persist${config.services.forgejo.stateDir}  0750 forgejo forgejo -"
      ];
    })

    (lib.mkIf (lineage.has.usage "Nextcloud") {
      services = {
        nginx.virtualHosts.${config.services.nextcloud.hostName} = {
          forceSSL = true;
          enableACME = true;
        };
        nextcloud = {
          enable = true;
          configureRedis = true;
          appstoreEnable = true;
          autoUpdateApps.enable = true;
          package = pkgs.nextcloud32;
          hostName = "cloud.${domain}";
          https = true;
          config = {
            adminuser = "admin";
            adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
            dbtype = "sqlite";
          };
        };
      };

      environment.persistence."/nix/persist".directories = [
        config.services.nextcloud.datadir
      ];

      systemd.tmpfiles.rules = [
        "d /nix/persist${config.services.nextcloud.datadir}  0750 nextcloud nextcloud -"
      ];
    })

    # Setups n8n, a self-hosted workflow automation tool
    (lib.mkIf (lineage.has.usage "n8n") {
      services =
        let
          port = "5678";
        in
        {
          nginx.virtualHosts."n8n.${domain}" = {
            enableACME = true;
            forceSSL = true;
            extraConfig = "client_max_body_size 16m;";
            locations."/".proxyPass = "http://localhost:${port}";
          };
          n8n = {
            enable = true;
            openFirewall = true;
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
          "granite4:3b"
          "lfm2.5-thinking:1.2b"
          "phi4-mini-reasoning:3.8b"
          "phi4-mini:3.8b"
          "qwen3-vl:4b"
          "qwen3-vl:8b"
          "qwen3:0.6b"
          "qwen3:4b"
          "qwen3:8b"
          "qwen3:14b"
          "gemma3n:e2b"
          "gemma3:4b"
        ];
      };

      environment.persistence."/nix/persist".directories = [ "/var/lib/private" ];
      systemd.tmpfiles.rules = [
        "d /var/lib/private/ollama 0700 ollama ollama -"
      ];
    })

    # Hosts a minecraft server
    (lib.mkIf (lineage.has.usage "Minecraft") {
      networking.firewall = {
        allowedTCPPorts = [ 25565 ];
        allowedUDPPorts = [ 19132 ];
      };

      programs.java = {
        enable = true;
        binfmt = true;
        package = pkgs.jdk21_headless;
      };
    })

    # Setups a Phantom, a proxy to connect game consoles to custom hosted servers
    (lib.mkIf (lineage.has.usage "Minecraft Proxy") {
      environment.systemPackages = [ pkgs.phantom ];

      networking.firewall.allowedUDPPorts = [ 19132 ];

      # Creates a systemd service to run the proxy on
      systemd.services.phantom = {
        description = "Phantom Bedrock Proxy";
        after = [ "network.target" ];
        wants = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = "${pkgs.phantom-bin}/bin/phantom-linux --server jameshollister.org:19132";
          Restart = "always";
          RestartSec = "5s";
          User = "phantom";
          Group = "phantom";
          KillSignal = "SIGINT";
        };
      };

      # Creates a user to run the systemd service with
      users = {
        users.phantom = {
          isSystemUser = true;
          group = "phantom";
        };

        groups.phantom = { };
      };
    })

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
      environment.systemPackages = [
        pkgs.wakeonlan
      ];
    })
  ];
}

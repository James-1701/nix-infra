{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  isLaptop = lineage.has.form "Laptop";
  isDesktop = lineage.has.usage "Desktop";
  hasSSH = lineage.has.usage "SSH";
in
{
  config = lib.mkMerge [
    {
      # General networking settings
      networking = {
        enableIPv6 = true;
        useNetworkd = true;
        usePredictableInterfaceNames = true;
        resolvconf.enable = false;
        wireless.enable = lib.mkForce (isLaptop && isDesktop);
        nat = {
          enable = true;
          enableIPv6 = true;
        };

        # Uses IPv4 over 6 if possible, because my ISP has terrible IPv6
        getaddrinfo = {
          enable = true;
          precedence."::ffff:0:0/96" = 100;
        };

        # Firewall setup
        # The firewall is very strict by default
        nftables.enable = true;
        firewall = {
          enable = true;
          allowPing = false;
          checkReversePath = "strict";
          rejectPackets = false;
          logReversePathDrops = true;
          logRefusedPackets = true;
          logRefusedConnections = true;
          logRefusedUnicastsOnly = false;
          allowedTCPPorts = lib.mkIf hasSSH config.services.openssh.ports;
          trustedInterfaces = lib.mkIf config.services.tailscale.enable [ "tailscale0" ];
        };
      };

      services = {

        # VM guests do not need time synchronization services they use hosts time
        timesyncd.enable = !(lineage.has.form "VM");

        # Tailscale is a private mesh network that connects all my systems together
        tailscale = {
          enable = true;
          useRoutingFeatures = "none";
          openFirewall = false;
          interfaceName = "tailscale0";
          authKeyFile = config.sops.secrets.tailscale-auth-key.path;

          # Allows SSH connections between all tailscale devices
          extraUpFlags = [ "--ssh" ];
        };

        # Setup SSH server for systems that need it
        openssh = {
          enable = hasSSH;
          allowSFTP = true;
          generateHostKeys = true;
          ports = [ 22 ];
          settings = {
            UsePAM = true;
            X11Forwarding = false;
            PermitRootLogin = "no";
            PasswordAuthentication = lineage.has.usage "Password SSH Login";
            KbdInteractiveAuthentication = false;
          };

          # Ensures the host keys are stored directly in persist storage for access in early boot
          hostKeys = [
            {
              path = "/nix/persist/etc/ssh/ssh_host_rsa_key";
              type = "rsa";
              bits = 4096;
            }
            {
              path = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
        };

        # Avahi is used for discovering devices on the local network
        avahi = {
          enable = (lineage.has.usage "Printing") || (lineage.has.usage "Print Server");
          nssmdns4 = true;
          nssmdns6 = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
          };
        };

        # Systemd resolved provides per-interface and split DNS routing;
        # Upstream resolution is delegated to dnscrypt-proxy for encryption and policy
        resolved = {
          enable = !(lineage.has.usage "Unbound") && !(lineage.has.form "WSL");
          settings.Resolve = {
            LLMNR = "true";
            Domains = "~.";

            # DNSCrypt Proxy does the Encryption so its disabled here
            DNSSEC = "false";
            DNSOverTLS = "opportunistic";

            # Ensures DNS gets delegated to DNSCrypt Proxy
            DNS = [
              "127.0.0.1"
              "::1"
            ];
          };
        };

        # DNSCrypt Proxy is an encrypted, secure and lightweight DNS Resolver
        # This does the DNS resolution for the system
        dnscrypt-proxy = {
          enable = true;
          settings = {
            ipv6_servers = config.networking.enableIPv6;
            block_ipv6 = !config.networking.enableIPv6;
            enable_hot_reload = false;
            odoh_servers = true;
            require_dnssec = true;
            require_nolog = true;
            require_nofilter = true;
            http3 = true;
            cache = true;
            ignore_system_dns = false;
            anonymized_dns.skip_incompatible = true;
            monitoring_ui = {
              enabled = false;
              enable_query_log = false;
            };
            server_names = [
              "quad9-dnscrypt-ip4-filter-pri"
              "quad9-doh-ip4-port443-filter-pri"
              "quad9-doh-ip6-port443-filter-pri"
              "quad9-doh-ip6-port5053-filter-pri"
            ];

            # Listens for packets from systemd resolved
            listen_addresses = [
              "127.0.0.1:53"
              "[::1]:53"
            ];
          };
        };
      };

      environment = {

        # Allows first ssh login to not require prompt
        etc."ssh/ssh_config".text = ''
          Host *
              StrictHostKeyChecking accept-new
        '';

        # Persists tailscale as well as system and user ssh keys
        persistence."/nix/persist" = {
          directories = [ "/var/lib/tailscale" ];
          files = [
            "/etc/machine-id"
            "/etc/ssh/ssh_host_rsa_key"
            "/etc/ssh/ssh_host_rsa_key.pub"
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_ed25519_key.pub"
          ];
          users = lib.mapAttrs (_: _: { directories = [ ".ssh" ]; }) (
            lib.filterAttrs (_: user: user.persistence == "default") config.internal.users
          );
        };

        # Some useful tools for pen testing and cyber classes
        systemPackages = lib.mkIf (lineage.has.usage "Hacking") (
          with pkgs;
          [
            angryipscanner
            aircrack-ng
            metasploit
            wireshark
            bettercap
            netcat
            nmap
          ]
        );
      };
    }

    (lib.mkIf (!isDesktop) {

      # Uses networkd for servers
      systemd.network.enable = true;

      networking = {

        # Laptops used for hosting use IWD instead of WPA Supplicant
        wireless.iwd = lib.mkIf isLaptop {
          enable = true;
          settings = {
            Network = {
              EnableIPv6 = config.networking.enableIPv6;
              RoutePriorityOffset = 300;
            };
            General = {
              EnableNetworkConfiguration = true;
              RoamThreshold = -75;
              RoamThreshold5G = -80;
            };
            Scan.DisablePeriodicScan = true;
            Settings.AutoConnect = true;
          };
        };
      };
      environment.persistence."/nix/persist".directories = lib.mkIf isLaptop [
        "/var/lib/iwd"
      ];
    })

    (lib.mkIf isDesktop {
      networking = {

        # Allows Miracast thought firewall
        firewall = {
          allowedTCPPorts = [
            7236
            7250
          ];
          allowedUDPPorts = [
            67
            5353
          ];
          allowedUDPPortRanges = [
            {
              from = 32768;
              to = 60999;
            }
          ];
        };

        # Network manager is the standard networking tool for desktops
        networkmanager = {
          enable = true;
          dns = "systemd-resolved"; # Uses the systemd resolved resolver setup
          dhcp = "internal";
          connectionConfig."ipv6.ip6-privacy" = 2;
          ethernet.macAddress = "random";
          wifi = {
            powersave = true;
            macAddress = "random";
            scanRandMacAddress = true;
            backend = "wpa_supplicant"; # Uses WPA_supplicant over IWD for miracast
          };
          settings = {
            connectivity.enabled = false;
            main.rc-manager = lib.mkDefault "file";
          };
        };

        # Uses Networkmanager's DHCP over dhcpcd
        dhcpcd = {
          enable = false;
          extraConfig = "nohook resolv.conf";
        };
      };

      # These can hang boot sometimes and arent really needed so we disable it
      systemd.services = {
        NetworkManager-wait-online.enable = false;
        systemd-networkd-wait-online.enable = lib.mkForce false;
      };

      environment = {
        persistence."/nix/persist".directories = [ "/etc/NetworkManager/system-connections" ];

        # Installs my university PEAP + MSCHAPv2 WiFi certificate
        systemPackages = with pkgs; [ gvsu-cert ];
      };
    })
  ];
}

/*
  NixOS Lineage Database

  This file acts as the source of truth for system taxonomy. It defines hierarchical
  trees of hardware and software traits. The framework uses this database to
  expand minimal host definitions into full system configurations via implication.

  Core Functionalities:
  1. Path Implication: Selecting a node (e.g., specific CPU model) automatically
  activates all parent nodes (Family, Vendor, Architecture) in the resulting configuration.
  2. Cross-Tree Dependency: A node in one tree (e.g., Form Factor) can strictly
  imply values in other trees (CPU, GPU) via the `implies` attribute.
  3. Strict Validation: Trees defined under `strict` enforce schema compliance;
  hostfiles cannot declare values for these keys that do not exist here.

  Usage:
  Consumed by the Lineage logic engine to generate:
  - `lineage.traits.<key>`: Resolved lists of attributes (hierarchical & inferred traits).
  - `lineage.has.<key> "<Input Value>"`: Functions for checking trait existence in modules.
*/

{
  strict = {
    form = {
      Laptop = {
        "Acer Predator PH315-52" = {
          _metadata.implies = {
            cpu = "i7 9750H";
            gpu = "GTX 1660 Ti";
            ram = 16;
          };
        };
        "Dell Latitude 7370" = {
          _metadata.implies = {
            cpu = "m7 6Y75";
            ram = 8;
          };
        };
        "2-in-1" = {
          "Hp Spectre eu0000" = {
            _metadata.implies = {
              cpu = "Ultra 7 155H";
              ram = 32;
              fingerprint = false;
            };
          };
        };
      };
      SBC = {
        "Raspberry Pi 4 Model B" = {
          _metadata.implies = {
            cpu = "BCM2711";
          };
        };
      };
      VM = {
        WSL = { };
        QEMU = { };
        HyperV = { };
      };
      VPS = {
        "Microsoft Azure" = {
          _metadata.implies = {
            form = "HyperV";
          };
        };

        # These cloud providers use KVM/QEMU.
        "Oracle Cloud Infrastructure" = {
          _metadata.implies = {
            form = "QEMU";
          };
        };
        "Google Compute Engine" = {
          _metadata.implies = {
            form = "QEMU";
          };
        };
        "Digital Ocean Droplet" = {
          _metadata.implies = {
            form = "QEMU";
          };
        };
      };
    };

    cpu = {
      x86_64 = {
        Intel = {
          "Meteor Lake" = {
            "Ultra 7 155H" = {
              _metadata.implies = {
                gpu = "Arc Graphics";
              };
            };
          };
          "Coffee Lake" = {
            "i7 9750H" = {
              _metadata.implies = {
                gpu = "UHD Graphics 630";
              };
            };
          };
          Skylake = {
            "m7 6Y75" = {
              _metadata.implies = {
                gpu = "HD Graphics 515";
              };
            };
          };
          "Bay Trail" = {
            "Celeron N2840" = {
              _metadata.implies = {
                gpu = "Z3700 Series";
              };
            };
          };
        };
        AMD = {
          "Zen 4" = {
            Genoa = {
              "EPYC 9J14" = { };
            };
          };
          "Zen 2" = {
            Rome = {
              "EPYC 7B12" = { };
            };
          };
        };
      };

      # Arm is fragmented; vendors use shared cores, so we split the Vendors and Cores.
      aarch64 = {

        # Vendors
        Broadcom = {
          BCM2711 = {
            _metadata.implies = {
              cpu = "Cortex-A72";
            };
          };
        };

        Ampere = {
          Altra = {
            Q80-30 = { };
          };
        };

        # Cores
        ARM = {
          ARMv8-A = {
            Cortex-A57 = { };
            Cortex-A72 = { };
          };
        };
      };
    };

    gpu = {
      Intel = {
        Xe = {
          Xe-LPG = {
            "Gen12.7" = {
              "Arc Graphics" = { };
            };
          };
        };
        Gen9 = {
          "UHD Graphics 630" = { };
          "HD Graphics 515" = { };
        };
        "Gen7.5" = {
          "Z3700 Series" = { };
        };
      };
      Nvidia = {
        Turing = {
          "GTX 1660 Ti" = { };
        };
      };
    };

    storage = {
      SSD = {
        NVMe = { };
      };
      HDD = { };
      Virtio = { };

      SMART = { };
    };

    boot = {
      UEFI = {
        "Secure Boot" = { };
      };
      BIOS = {
        "BIOS (Legacy MBR)" = { };
      };
    };
  };

  usage = {
    Graphics = {
      Ollama = { };
      Desktop = {
        Wayland = {
          KDE = {
            AeroThemePlasma = { };
          };
          Gnome = { };
          Cosmic = { };
        };
        X11 = { };
      };
    };
    SSH = {
      Server = {
        Unbound = { };
        Minecraft = { };
        "Wake on Lan" = { };
        "Minecraft Proxy" = { };
        "Nix Remote Builder" = { };
        "Password SSH Login" = { };
        "Print Server" = {
          _metadata.implies = {
            usage = "Printing";
          };
        };
        "Edge Proxy" = {
          Nginx = {
            n8n = { };
            Forgejo = { };
            OpenClaw = { };
            Nextcloud = { };
          };
          Caddy = { };
          Traefik = { };
        };
      };
    };
  };
}

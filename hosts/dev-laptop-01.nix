# Host Manifest: HP Spectre x360
# Role: Personal Laptop / Testing / Development
#
# See `hosts/README.md` for schema details.
#
# Hardware Quirks & Overlays:
# Upstream Reference: https://github.com/aigilea/hp_spectre_x360_14_eu0xxx
# - Wi-Fi: Implements PCI reset script to resolve suspend/resume instability.
# - Input: Enables palm rejection via systemd service.

{
  # 1. Hardware
  # Note: 'form' strictly implies CPU and RAM.
  boot = "Secure Boot";
  form = "Hp Spectre eu0000";

  # 2. Storage
  disks = [ "/dev/nvme0n1" ];
  storage = [
    "NVMe"
    "SMART"
  ];

  # 3. System Profile
  usage = [
    "fprint"
    "libvirt"
    "Waydroid"
    "Development"
    "KDE"
    "Printing"
    "Nix Remote Builder"
  ];

  # 4. Users
  users = {
    primary = "james";

    # Primary User Account
    info = {
      james = {
        description = "James Hollister";
        passwd = "/run/secrets-for-users/primary-user-password";
        packages = {
          nixpkgs = [

            # Productivity
            "gnome-console"
            "vscode-fhs"
            "bitwarden-desktop"
          ];
          flatpaks = [

            # Productivity
            "com.microsoft.Edge"

            # Leisure
            "com.valvesoftware.Steam"
            "com.heroicgameslauncher.hgl"
            "org.prismlauncher.PrismLauncher"
          ];
        };
      };

      # Secondary User Account
      madi = {
        description = "Most Beautiful Girlfriend";
        persistence = "full";
        packages.flatpaks = [
          "com.google.Chrome"
        ];
      };

      # Guest Account
      guest = {
        description = "Guest User";
        persistence = "none";
      };
    };
  };

  # 5. Software Packages
  packages = {
    nixpkgs = [

      # System
      "nautilus"
      "gnome-software"
      "gnome-control-center"
    ];
    flatpaks = [

      # System
      "org.gnome.Weather"
      "org.gnome.Calendar"
      "org.gnome.NetworkDisplays"
    ];
  };

  # 6. Host-Specific Extensions
  modules =
    { pkgs, ... }:
    {

      # 6.1 Services
      services.sunshine = {
        enable = true;
        autoStart = false;
        capSysAdmin = true;
        openFirewall = true;
      };
      environment.persistence."/nix/persist".users.james.directories = [ ".config/sunshine" ];

      # 6.2 Fixes
      # QUIRK: ELAN Touchpad doesnt reject accidental palm touches
      # Solution: Apply quirk '4160' to the input device
      services.udev.extraRules = ''
        # ELAN Touchpad Palm Rejection Quirk
        ACTION=="bind", SUBSYSTEM=="hid", DRIVER=="hid-multitouch", KERNEL=="0018:04F3:310A.*", ATTR{quirks}="4160"
      '';

      # QUIRK: Intel AX211 Wi-Fi Suspend Crash
      # Solution: Force remove/rescan PCI bus on sleep/wake
      # The powerManagement module is the proper way to do this, but the systemd service seems to be far more robust and consistent
      systemd.services =
        let
          wifi-pci-reset = pkgs.writeShellScript "wifi-pci-reset" ''
            PCI="0000:01:00.0"
            ACTION="$1"

            case "$ACTION" in
              pre)
                ${pkgs.coreutils}/bin/echo 1 > "/sys/bus/pci/devices/$PCI/remove"
                ;;
              post)
                ${pkgs.coreutils}/bin/sleep 3
                ${pkgs.coreutils}/bin/echo 1 > /sys/bus/pci/rescan
                ;;
            esac
          '';
        in
        {
          pci-reset = {
            description = "Reset Wi-Fi PCI on suspend/resume";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${wifi-pci-reset} pre";
              ExecStop = "${wifi-pci-reset} post";
            };
            before = [ "sleep.target" ];
            wantedBy = [ "sleep.target" ];
          };
        };
    };
}

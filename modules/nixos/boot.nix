{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  isUEFI = lineage.has.boot "UEFI";

  disks = lineage.traits.disks or [ ];

  # Gets the disks to later install the bootloader on
  # List of attribute sets
  diskList =
    if builtins.isString disks then
      [ { device = disks; } ]
    else if builtins.isList disks then
      map (disk: { device = disk; }) disks
    else
      lib.mapAttrsToList (_: disk: disk) disks;
in
{
  boot = {

    # General Boot settings
    consoleLogLevel = 0;
    kernelParams = [ "console=tty1" ];
    loader = {
      timeout = 1;

      # BIOS systems use GRUB
      grub = {
        enable = lineage.has.boot "BIOS";
        zfsSupport = true;
        useOSProber = false;
        enableCryptodisk = true;
        configurationLimit = 10;
        gfxpayloadBios = "keep";
        gfxmodeBios = "auto";
        efiSupport = false;
        default = "0";

        # mirroredBoots installs the bootloader across all devices for redundancy on multi disk systems
        mirroredBoots = lib.mkForce (
          lib.imap1 (i: d: {
            path = if i == 1 then "/boot" else "/boot-fallback-disk${toString i}";
            devices = [ d.device ];

            # When building disko images installs the bootloader to the virtual disk being built, not the original host disk name(s)
          }) (if (config.system.build ? diskoImages) then [ { device = "/dev/vda"; } ] else diskList)
        );
      };

      # UEFI systems all use systemd boot
      systemd-boot = {
        enable = !(lineage.has.boot "Secure Boot") && isUEFI;
        editor = false;
        consoleMode = "keep";
        configurationLimit = 10;
      };
      efi = {
        canTouchEfiVariables = isUEFI;
        efiSysMountPoint = "/boot";
      };
    };
    initrd = {
      enable = !(lineage.has.form "WSL"); # WSL doesnt use initrd

      # Some basic kernel modules to boot most devices
      availableKernelModules = [
        "usb_storage"
        "rtsx_pci_sdmmc"
        "sdhci_pci"
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "uas"
        "sd_mod"
        "sr_mod"
        "sdhci_acpi"
      ];

      # General settings for initrd
      verbose = true;
      includeDefaultModules = true;
      kernelModules = [ ];
      checkJournalingFS = true;
      inherit (config.boot) supportedFilesystems;
      compressor = "zstd";
      unl0kr = {
        enable = false;
        allowVendorDrivers = true;
      };

      # systemd based initrd has significantly more features and capabilities
      systemd = {
        enable = true;
        tpm2.enable = config.security.tpm2.enable;
        dmVerity.enable = true;
        network = {
          enable = false;
          wait-online.enable = lib.mkForce false;
        };
      };
    };
  };

  # For multi disk UEFI systems only
  # Mirrors changes to the EFI system partition across all the drives with rsync triggered by systemd.path
  systemd = lib.mkIf (((builtins.length diskList) > 1) && isUEFI) {

    # Detects changes
    paths.mirror-boot-watch = {
      enable = true;
      description = "Watch /boot for Bootloader Updates";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/boot";
        Unit = "mirror-boot-sync.service";
      };
    };

    # Syncs changes
    services.mirror-boot-sync = {
      enable = true;
      description = "Sync /boot to Fallback Mirrors";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "sync-boot-mirrors" ''
          set -euo pipefail

          for dir in /boot-fallback-*; do
            ${pkgs.rsync}/bin/rsync -a --delete /boot/ "$dir/" > /dev/null
          done
        '';
      };
    };
  };
}

{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  isDesktop = lineage.has.usage "Desktop";

  disks = lineage.traits.disks or [ ];

  # Normalizes the disks input for later use
  preDiskList =
    if builtins.isString disks then
      [ { device = disks; } ]
    else if builtins.isList disks then
      map (disk: { device = disk; }) disks
    else
      lib.mapAttrsToList (_: disk: disk) disks;

  # Gives the disk an identifier and sets the default boot one
  diskList = builtins.listToAttrs (
    lib.imap1 (i: diskConfig: {
      name = "disk${toString i}";
      value = diskConfig // {
        defaultBoot = i == 1;
      };
    }) preDiskList
  );

  # Name of the zpool
  zpoolName = "zp0";
in
{
  # Ensures "/nix/persist" has neededForBoot set
  fileSystems."/nix/persist".neededForBoot = true;

  # Disko Declaratively partitions disks and builds the `fileSystems` block for them
  disko = {

    # Needed to build disk images
    memSize = lineage.traits.ram * 1024 * 4;

    devices = {

      # Mounts / to tmpfs for an impermanace setup, later I may make this Opt-Out
      nodev."/" = {
        fsType = "tmpfs";
        mountpoint = "/";
        mountOptions = [
          "rw"
          "nodev"
          "nosuid"
          "noatime"
          "nouser"
          "mode=1555"
        ];
      };

      disk = lib.mapAttrs (name: diskConfig: {
        type = "disk";
        inherit (diskConfig) device; # Gets the device
        imageSize = if lineage.has.usage "Desktop" then "16G" else "4G";
        content =

          # UEFI systems use GPT disks
          if (lineage.has.boot "UEFI") then
            {
              type = "gpt";
              partitions = {
                EFI = {
                  label =

                    # Sets a separate label for each EFI system partition
                    if diskConfig.defaultBoot then
                      "EFI System Partition"
                    else
                      "Fallback EFI System Partition on ${name}";
                  size = "512M";
                  type = "EF00";
                  priority = 1;
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountOptions = [ "noatime" ];
                    extraArgs = [
                      "-n"
                      "EFI"
                    ];

                    # Only one drive gets mounted to /boot the others to /boot-fallback-<n>
                    mountpoint = if diskConfig.defaultBoot then "/boot" else "/boot-fallback-${name}";
                  };
                };

                # Adds the ZFS zpool to the disk
                ZFS = {
                  label = "${name} ZFS Pool";
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = zpoolName;
                  };
                };
              };
            }

          # Creates MBR layout for BIOS systems that need it
          # Note that this causes an evaluation warning because disko prefers GPT
          else if (lineage.has.boot "BIOS (Legacy MBR)") then
            {
              type = "table";
              format = "msdos";
              partitions = [
                {
                  # Adds the FAT32 bootloader partition with room for the BIOS Boot in the 1st MB
                  start = "1M";
                  end = "512M";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountOptions = [ "noatime" ];
                    extraArgs = [
                      "-n"
                      "BOOT"
                    ];

                    # Only one drive gets mounted to /boot the others to /boot-fallback-<n>
                    mountpoint = if diskConfig.defaultBoot then "/boot" else "/boot-fallback-${name}";
                  };
                }
                {
                  # Adds the ZFS zpool to the disk
                  start = "512M";
                  end = "100%";
                  content = {
                    type = "zfs";
                    pool = zpoolName;
                  };
                }
              ];
            }

          # Creates GPT layout for most BIOS systems
          else
            {
              type = "gpt";
              partitions = {
                BIOS = {

                  size = "1M";
                  type = "EF02";
                  priority = 1;

                  # Sets a separate label for each BIOS Boot system partition
                  label =
                    if diskConfig.defaultBoot then "BIOS Boot Partition" else "Fallback BIOS Boot Partition on ${name}";
                };
                BOOT = {
                  size = "512M";
                  type = "8300";

                  # Sets a separate label for each Bootloader partition
                  label = if diskConfig.defaultBoot then "Boot Partition" else "Fallback Boot Partition on ${name}";

                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountOptions = [ "noatime" ];
                    extraArgs = [
                      "-n"
                      "BOOT"
                    ];

                    # Only one drive gets mounted to /boot the others to /boot-fallback-<n>
                    mountpoint = if diskConfig.defaultBoot then "/boot" else "/boot-fallback-${name}";
                  };
                };

                # Adds the ZFS zpool to the disk
                ZFS = {
                  label = "${name} ZFS Pool";
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = zpoolName;
                  };
                };
              };
            };
      }) diskList;

      zpool.${zpoolName} = {

        # Basic settings for the ZFS Dataset
        type = "zpool";
        mode = lineage.traits.zfsMode or "";
        options.ashift = "12";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          relatime = "off";
          atime = "off";
          xattr = "sa";
          dnodesize = "auto";
          normalization = "formD";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
        }

        # Laptops with GUI desktop environments require disk encryption.
        # On-site platforms are excluded from this threat model.
        // lib.optionalAttrs (isDesktop && (lineage.has.form "Laptop")) {
          encryption = "on";
          keyformat = "passphrase";
        };

        # Sets up all the ZFS Datasets for the zpool
        datasets = {
          "system" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              canmount = "off";
            };
          };
          "system/persist" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              canmount = "off";
            };
          };
          "system/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              canmount = "noauto";
              compression = "lz4";
              snapdir = "visible";
            };
          };
          "system/persist/root" = {
            type = "zfs_fs";
            mountpoint = "/nix/persist";
            options = {
              canmount = "noauto";
              snapdir = "visible";
            };
          };
          "system/persist/home" = {
            type = "zfs_fs";
            mountpoint = "/nix/persist/home";
            options = {
              canmount = "noauto";
              snapdir = "visible";
            };
          };
          "system/nixos-config" = {
            type = "zfs_fs";
            mountpoint = "/etc/nixos";
            options.canmount = "noauto";
          };
        };
      };
    };
  };

  boot = {

    # Setup /tpm
    tmp = {
      useTmpfs = true;
      tmpfsSize = "75%";
      cleanOnBoot = true;
    };

    # Basic ZFS setup
    zfs = {
      extraPools = [ ];
      package = pkgs.zfs;
      forceImportAll = false;
      forceImportRoot = config.boot.zfs.forceImportAll;
      allowHibernation = false;
      requestEncryptionCredentials = true;

      # This setting ensures VMs work correctly with ZFS
      # Documentation Reference: https://openzfs.github.io/openzfs-docs/Project%20and%20Community/FAQ.html#selecting-dev-names-when-creating-a-pool-linux
      devNodes = "/dev/disk/by-path";
    };
    supportedFilesystems = [
      "zfs"
    ]

    # Desktop systems are more likely to need access to Microsoft filesystems
    ++ lib.optionals isDesktop [
      "ntfs"
      "fat"
      "exfat"
    ];
    kernelModules = lib.mkIf isDesktop [ "ntfs3" ];

    kernelParams =
      let
        gb = 1024 * 1024 * 1024;
        ratio = if (lineage.has.usage "Desktop") then 0.5 else 0.8; # Desktops get less RAM for ARC
        arcSize = builtins.floor (lineage.traits.ram * gb * ratio);
      in
      [
        # Sets ZFS settings for easier pool import and for larger ARC
        "zfs_force=1"
        "zfs.zfs_arc_max=${toString arcSize}"
      ];
  };

  services = {
    fstrim.enable = lineage.has.storage "SSD"; # trim is only for SSDs

    # Sets up ZFS auto snapshot with zrepl instead of autoSnapshot
    zfs = {
      autoSnapshot.enable = lib.mkForce false;
      trim.enable = lineage.has.storage "SSD";
      autoScrub.enable = true; # Detects Bit rot
    };
    zrepl = {
      enable = true;
      settings.jobs = [
        {
          name = "${zpoolName}-snapshots";
          type = "snap";
          filesystems."${zpoolName}<" = true; # Enables the full zpool
          snapshotting = {
            type = "periodic";
            interval = "15m";
            prefix = "auto_";
            timestamp_format = "human";
          };
          pruning.keep = [
            {
              type = "grid";
              grid = "4x15m | 2x1h | 1x1d | 1x7d | 1x30d";
              regex = "^auto_.*";
            }
          ];
        }
      ];
    };
    smartd = {
      enable = lineage.has.storage "SMART";
      notifications.systembus-notify.enable = lineage.has.usage "Desktop";
    };
  };

  # Enables and disables relevant services
  systemd.services = {
    zfs-zed.enable = true;
    zfs-mount.enable = true;
    zfs-share.enable = false;
  };

  environment = {
    # Prevents dozens of mountpoints from showing up in tools
    persistence."/nix/persist".hideMounts = true;

    systemPackages = [

      # Adds the ZFS tools to the PATH
      config.boot.zfs.package
    ]

    # Desktop systems are more likely to need tools for Microsoft filesystems
    ++ lib.optionals isDesktop (
      with pkgs;
      [
        ntfs3g
        dosfstools
        exfatprogs
      ]
    );
  };

  # Ensure hostId is fixed for ZFS pools
  networking.hostId = "4e98920d";
}

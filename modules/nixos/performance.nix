{
  config,
  pkgs,
  lib,
  lineage,
  ...
}:

let
  isDesktop = lineage.has.usage "Desktop";
  isLaptop = lineage.has.form "Laptop";
  isGuiLaptop = isDesktop && isLaptop;
  isPhysicalServer = !isDesktop && !(lineage.has.form "VM");
  hasSwap = false; # Temporsystemdarily disables swap on all systems
in
{
  powerManagement = {
    enable = !(lineage.has.form "WSL"); # WSL doesnt do any power management

    # Basic powersave settings
    cpuFreqGovernor = "powersave";
    scsiLinkPolicy = lib.mkIf (!isPhysicalServer) "med_power_with_dipm";
  };

  # Swap on ZFS is tricky and is temporarily disabled
  swapDevices = lib.mkIf hasSwap [
    {
      device = "/dev/zvol/zp0/system/swap";
      options = [ "discard" ];
      discardPolicy = "both";
      randomEncryption = {
        enable = true;
        allowDiscards = true;
      };
    }
  ];

  # Zram gives compressed RAM, its essentially free slower RAM when more is needed
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    priority = 100;
    memoryPercent = 200;
  };

  # OOM kills processes when the system is under heavy memory pressure
  systemd.oomd = {
    enable = lib.mkForce true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
  };

  services = {
    irqbalance.enable = true; # Spreads interrupts across CPU cores

    # Desktop specific power management tools
    upower.enable = isDesktop;
    system76-scheduler.enable = isDesktop;
    power-profiles-daemon.enable = isDesktop;

    # Bare metal servers use TLP for power management
    tlp = {
      enable = isPhysicalServer;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        AHCI_RUNTIME_PM_ON_AC = "on";
        DISK_APM_LEVEL_ON_AC = "254 254";
        DISK_SPINDOWN_TIMEOUT_ON_AC = "0";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "med_power_with_dipm";

        RUNTIME_PM_ON_AC = "on";
      };
    };

    # I use systemd OOMD instead
    earlyoom = {
      enable = false;
      enableNotifications = true;
    };

    # Enables some powersave settings for hardware
    udev.extraRules = lib.concatStrings [
      ''
        SUBSYSTEM=="pci", ATTR{power/control}="auto"
        SUBSYSTEM=="ata_port", KERNEL=="ata*", ATTR{device/power/control}="auto"
        ACTION=="add|change", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
      ''
      (lib.optionalString isGuiLaptop ''ACTION=="add|change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", TAG+="systemd", ENV{SYSTEMD_WANTS}="apply-power-profile.service"'')
    ];
  };

  # Allows limited real-time scheduling priority for user processes needing low-latency workloads
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = 1;
    }
  ];

  boot = {
    kernel = {
      sysctl = lib.mkMerge [
        {
          # Higher interactive performance vs throughput
          "vm.dirty_writeback_centisecs" = 6000;
          "vm.laptop_mode" = 5;
          "vm.dirty_ratio" = 5;
          "vm.dirty_background_ratio" = 3;
          "vm.max_map_count" = 2147483642;
          "vm.compaction_proactiveness" = 1;
          "vm.zone_reclaim_mode" = 0;
          "vm.page_lock_unfairness" = 1;
        }

        # Settings for swap performance
        (lib.mkIf hasSwap {
          "vm.swappiness" = 1;
          "vm.vfs_cache_pressure" = 1;
        })
      ];

      # Enable multi-generation LRU for improved memory reclaim behavior
      sysfs.kernel.mm.lru_gen.enabled = 5;
    };

    # General powersave settings for kernel modules to apply
    extraModprobeConfig = lib.mkMerge [
      ''
        options processor ignore_ppc=1
        options usbcore autosuspend=1
      ''
      (lib.mkIf (lineage.has.cpu "Intel") "options snd_hda_intel power_save=1")
      (lib.mkIf isLaptop ''
        options iwlwifi power_save=1
        options iwlmvm power_scheme=3
      '')
    ];

    kernelParams = [
      # Optimizes for performance and latency
      "nowatchdog"
      "nmi_watchdog=0"
      "tsc=reliable"
      "clocksource=tsc"
      "preempt=full"

      # Reduces PCIe power usage
      "pcie_aspm.policy=powersupersave"
    ]

    # Enables Zswap for swap partitions/files
    ++ (lib.optionals hasSwap [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=25"
      "zswap.shrinker_enabled=1"
      "zswap.zpool=zbud"
    ])

    # Intel-specific CPU performance policy tuning
    ++ (lib.optionals (lineage.has.cpu "Intel") [ "intel_pstate=per_cpu_perf_limits" ])

    # Reduces latency on Desktops
    ++ (lib.optionals isDesktop [ "threadirqs" ]);
  };

  environment = {

    # Disable OpenGL vblank (vsync) to reduce latency and improve performance.
    # This may introduce screen tearing and is intended for performance-focused systems.
    etc."drirc".text = ''
      <driconf>
        <device>
          <application name="Default">
            <option name="vblank_mode" value="0" />
          </application>
        </device>
      </driconf>
    '';

    # Install CPU energy/performance tuning utility on x86_64 systems
    systemPackages = lib.optionals (lineage.has.cpu "x86_64") [
      config.boot.kernelPackages.x86_energy_perf_policy
    ];
  };

  # Systemd service to apply power profile based on AC power status
  systemd.services.apply-power-profile = lib.mkIf isGuiLaptop {
    description = "Apply power profile based on AC power status";
    after = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "apply-power-profile-sh" ''
        if ${pkgs.acpi}/bin/acpi -a | ${pkgs.gnugrep}/bin/grep -q "on-line"; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
        else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
        fi
      '';
    };
  };
}

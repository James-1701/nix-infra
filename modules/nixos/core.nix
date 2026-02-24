{
  lineage,
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

{
  system = {
    stateVersion = "26.05";

    # Enables daily auto upgrade
    autoUpgrade = {
      enable = true;
      flake = inputs.self.outPath;
      allowReboot = false;
      persistent = true;
      runGarbageCollection = true;
    };
  };

  # Sets the proper time zone and hardware clock functionality
  time = {
    timeZone = lib.mkForce "America/Detroit";
    hardwareClockInLocalTime = false;
  };

  # Enables the console for non WSL setups
  console = {
    enable = !(lineage.has.form "WSL");
    useXkbConfig = true;
    earlySetup = false;
  };

  services = {
    journald.console = "/dev/tty12"; # Enables journald output to the last TTY
    logrotate.enable = false; # Not needed with journald
    fwupd.enable = !(lineage.has.form "VM"); # Bare metal systems need firmware updates
  };

  # Ensures all firmware is installed
  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    firmware = with pkgs; [ linux-firmware ];
  };

  environment = {
    defaultPackages = lib.mkForce [ ]; # Ensures no random packages are installed

    # Common directories needing to be persisted
    persistence."/nix/persist".directories = [
      "/var/lib/nixos"
      "/var/log"
    ];
  };

  nixpkgs = {
    config.allowUnfree = true; # Allows proprietary software

    # Sets up the flake properly
    flake = {
      setNixPath = true;
      setFlakeRegistry = true;
    };
  };

  # Locale setup
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "C.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "C.UTF-8";
    };
  };

  boot = {

    # Used to boot the latest version of the Kernel that supports ZFS
    kernelPackages = lib.last (
      lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
        builtins.attrValues (
          lib.filterAttrs (
            name: kernelPackages:
            (builtins.match "linux_[0-9]+_[0-9]+" name) != null
            && (builtins.tryEval kernelPackages).success
            && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
          ) pkgs.linuxKernel.packages
        )
      )
    );

    # Enables sysrq
    kernel.sysctl."kernel.sysrq" = lib.mkForce 1;
  };

  # Disables documentation to save storage space and speed up build time
  documentation =
    let
      enable-docs = lineage.docs or false;
    in
    {
      enable = enable-docs;
      man = {
        enable = enable-docs;
        man-db.enable = enable-docs;
      };
      doc.enable = enable-docs;
      dev.enable = enable-docs;
      info.enable = enable-docs;
      nixos = {
        enable = enable-docs;
        includeAllModules = enable-docs;
        options.warningsAreErrors = false;
      };
    };

  programs = {
    nix-ld.enable = true; # Allows running unpatched dynamic binaries on NixOS

    # nh is a powerful nix CLI helper
    nh = {
      enable = true;
      flake = "/etc/nixos";
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 3d";
      };
    };

    # Sets up git
    git = {
      enable = true;
      config = {
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
        url."https://github.com/".insteadOf = [
          "gh:"
          "github:"
        ];
        user = {
          name = "James";
          email = "me@jamesx86.org";
        };
      };
    };
  };

  # Bypasses some non-fatal boot errors instead of going to a completely locked down shell
  systemd.enableEmergencyMode = false;

  nix = {

    # Enables distributed builds and setups up nix remote builders
    distributedBuilds = true;
    buildMachines =
      let
        protocol = "ssh-ng";
        sshUser = "nix-builder";
        mandatoryFeatures = [ ];

      in
      [
        {
          hostName = "dev-laptop-01";
          system = "x86_64-linux";
          inherit protocol sshUser mandatoryFeatures;
          maxJobs = 16;
          speedFactor = 2; # Later I will add a relative scaling system
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        }
        {
          hostName = "home-server-02";
          system = "x86_64-linux";
          inherit protocol sshUser mandatoryFeatures;
          maxJobs = 8;
          speedFactor = 1; # Later I will add a relative scaling system
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        }
        {
          hostName = "cloud-server-01";
          system = "aarch64-linux";
          inherit protocol sshUser mandatoryFeatures;
          maxJobs = 4;
          speedFactor = 2; # Later I will add a relative scaling system
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
      ];

    channel.enable = false; # Uses flakes instead of channels

    # Performance settings
    daemonIOSchedPriority = 7;
    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

    # Reduces nix store size
    optimise.automatic = true;
    gc = {
      automatic = !config.programs.nh.clean.enable;
      dates = "00:00";
      options = "--delete-older-than 5d";
      randomizedDelaySec = "8h";
      persistent = true;
    };

    # General nix settings
    settings = {
      lazy-trees = true; # Determinate Nix Exclusive
      sandbox = true;
      require-sigs = true;
      auto-optimise-store = true;
      warn-dirty = true;
      cores = 0;
      max-jobs = "auto";
      trusted-users = [ "root" ] ++ config.internal.superusers;
      experimental-features = [
        "parallel-eval" # Determinate Nix Exclusive
        "nix-command"
        "flakes"
        "cgroups"
      ];
      system-features = [
        "kvm"
        "nixos-test"
        "big-parallel"
        "nixos-test"
      ];
    };

    # Adds some extra binary caches and a quicker timeout
    extraOptions = ''
      connect-timeout = 5
      extra-substituters = https://devenv.cachix.org https://install.determinate.systems
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=
    '';
  };
}

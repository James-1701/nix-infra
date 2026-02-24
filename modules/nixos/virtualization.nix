{
  modulesPath,
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  isQemuGuest = lineage.has.form "QEMU";

  # Setting the qemu package to use here makes it easy to keep consistent
  qemu_package = pkgs.qemu_full;
in
{
  imports = lib.optionals isQemuGuest [
    "${modulesPath}/profiles/qemu-guest.nix"

    # I would like to use the following module at some point
    # It makes many changes and I dont currently have the time to debug and mkForce everything
    #
    # "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  config = lib.mkMerge [
    (lib.mkIf (lineage.has.form "HyperV" && !(lineage.has.form "Microsoft Azure")) {
      virtualisation.hypervGuest.enable = true;
    })

    (lib.mkIf isQemuGuest {
      services.qemuGuest.enable = true;

      # Sets the console to the serial console and sets the baud rate properly
      boot.kernelParams = lib.mkAfter [ "console=ttyS0,115200" ];
    })

    (lib.mkIf (lineage.has.usage "Waydroid") {
      virtualisation.waydroid.enable = true;

      # Ensures waydroid0 can communicate with host for proper networking
      networking.firewall.trustedInterfaces = [ "waydroid0" ];

      # Persists the needed directories
      environment.persistence."/nix/persist" = {
        directories = [ "/var/lib/waydroid" ];
        users = lib.mapAttrs (_: user: {
          directories = lib.mkIf (user.persistence == "default") [
            ".local/share/applications" # Persists Waydroid desktop entries (overbroad but necessary)
            ".local/share/waydroid"
          ];
        }) config.internal.users;
      };
    })

    (lib.mkIf (lineage.has.usage "libvirt") {
      programs.virt-manager.enable = true;
      environment = {
        persistence."/nix/persist".directories = [ "/var/lib/libvirt" ];
        systemPackages =
          with pkgs;
          [
            virtiofsd
            libguestfs
          ]
          ++ [
            qemu_package
          ];
      };

      # Ensures libvirt VMs can communicate with host for proper networking
      networking.firewall.trustedInterfaces = [ "virbr0" ];

      # Makes sure admin users can use it without root login
      users.groups = {
        libvirtd.members = config.internal.superusers;
        libvirt.members = config.internal.superusers;
        kvm.members = config.internal.superusers;
      };

      # Configures virtualization settings for proper setup and features
      virtualisation = {
        spiceUSBRedirection.enable = true;
        libvirtd = {
          enable = true;
          package = pkgs.libvirt;
          onBoot = "ignore";
          onShutdown = "shutdown";
          qemu = {
            package = qemu_package;
            runAsRoot = true;
            swtpm.enable = true;
            vhostUserPackages = [ pkgs.virtiofsd ];
          };
        };
      };

      # Ensures modules needed for QEMU VMs are loaded
      boot = {
        kernelModules = [ "vfio-pci" ];
        kernelParams = [ "iommu=pt" ];
        initrd.kernelModules = [
          "vfio"
          "vfio_iommu_type1"
          "vfio_pci"
          "vhost-net"
        ];
      };
    })
  ];
}

# Template Host Manifest
# Role: Copy this file to create a new machine configuration.
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = ""; # Firmware: "UEFI", "BIOS", "Secure Boot"
  form = ""; # Chassis: "Laptop", "Desktop", "Server", "QEMU", "Dell Latitude 7370"
  cpu = ""; # Arch/Model: "x86_64", "aarch64", "Intel", "i7 9750H"
  ram = 0; # System RAM in GB
  swap = true; # (Optional, Default: true) Boolean toggle to enable/disable swap

  # 2. Storage
  disks = ""; # Boot Device: "/dev/sda", "/dev/nvme0n1", or list for raid
  storage = [ ]; # (Optional) Technologies: "SSD", "HDD", "NVMe", "SMART", "LVM"
  zfsMode = ""; # (Optional, Default: "") Zfs mode: "", "mirror", "raid10", "raidz"

  # 3. System Profile
  usage = [ ]; # Traits: "Development", "Gnome", "Server", "libvirt"

  # 4. Users (Optional)
  users = {
    primary = "user"; # Name of the primary admin user
    info.user = {

      # Replace 'user' with actual username
      description = "";
      passwd = ""; # Path to secret or hashed string
      persistence = ""; # "default", "none", or "full"
      packages = {

        # Uses the same format as '5. Software Packages'
        nixpkgs = [ ];
        flatpaks = [ ];
      };
    };
  };

  # 5. Software Packages (Optional)
  packages = {
    nixpkgs = [ ]; # Nixpkgs: "bash", "coreutils", "gcc", can be found at: https://search.nixos.org/packages
    flatpaks = [ ]; # Flatpaks: "com.visualstudio.code", "io.dbeaver.DBeaverCommunity", can be found at: https://flathub.org
  };

  # 6. Host-Specific Extensions (Optional)
  modules = _: {

    # Standard Nixos modules here
  };
}

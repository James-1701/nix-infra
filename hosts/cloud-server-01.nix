# Host Manifest: Oracle Cloud VPS
# Role: Server Hosting, Testing
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "UEFI";
  form = "Oracle Cloud Infrastructure";
  cpu = "Q80-30";
  ram = 24;

  # 2. Storage
  disks = [ "/dev/sda" ];

  # 3. System Profile
  usage = [
    "Nix Remote Builder"
    "Prometheus"
    "Nextcloud"
    "Forgejo"
  ];
}

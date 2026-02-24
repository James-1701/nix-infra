# Host Manifest: Chromebook
# Role: None (obsolete)
#
# See `hosts/README.md` for schema details.

# WARNING: This hostfile is obsolete and has not been tested with the latest version of my configuration

{
  # 1. Hardware
  boot = "UEFI";
  form = "Laptop";
  cpu = "Celeron N2840";
  ram = 2;

  # 2. Storage
  disks = [ "/dev/mmcblk0" ];

  # 3. System Profile
  usage = [
    "Forgejo"
  ];
}

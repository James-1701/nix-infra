# Host Manifest: Digital Ocean Droplet VPS
# Role: None (obsolete)
#
# See `hosts/README.md` for schema details.

# WARNING: This hostfile is obsolete and has not been tested with the latest version of my configuration

{
  # 1. Hardware
  boot = "BIOS";
  form = "Digital Ocean Droplet";
  cpu = "x86_64";
  ram = 4;

  # 2. Storage
  disks = [ "/dev/vda" ];
  storage = [ "Virtio" ];

  # 3. System Profile
  usage = [
    "Minecraft"
    "Unbound"
  ];
}

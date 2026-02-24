# Host Manifest: Raspberry Pi
# Role: None (obsolete)
#
# See `hosts/README.md` for schema details.

# WARNING: This hostfile is obsolete and has not been tested with the latest version of my configuration

{
  # 1. Hardware
  # Note: 'form' implies CPU.
  boot = "BIOS";
  form = "Raspberry Pi 4 Model B";
  ram = 16;

  # 2. Storage
  disks = [ "/dev/mmcblk0" ];

  # 3. System Profile
  usage = [
    "Server"
  ];
}

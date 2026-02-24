# Host Manifest: QEMU x86_64 VM with ZFS Raid 0 on UEFI Firmware
# Role: Testing / Development
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "UEFI";
  form = "QEMU";
  cpu = "x86_64";
  ram = 8;
  swap = false;

  # 2. Storage
  disks = [
    "/dev/vda"
    "/dev/vdb"
  ];

  # 3. System Profile
  usage = [ "SSH" ];
}

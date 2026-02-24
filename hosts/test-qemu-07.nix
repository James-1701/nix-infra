# Host Manifest: QEMU aarch64 VM on UEFI Firmware
# Role: Testing / Development
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "UEFI";
  form = "QEMU";
  cpu = "aarch64";
  ram = 8;
  swap = false;

  # 2. Storage
  disks = [ "/dev/vda" ];

  # 3. System Profile
  usage = [ "SSH" ];
}

# Host Manifest: QEMU x86_64 VM on BIOS Firmware
# Role: Testing / Development
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "BIOS (Legacy MBR)";
  form = "QEMU";
  cpu = "x86_64";
  ram = 8;
  swap = false;

  # 2. Storage
  disks = [ "/dev/vda" ];

  # 3. System Profile
  usage = [ "SSH" ];
}

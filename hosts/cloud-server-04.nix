# Host Manifest: Microsoft Azure VPS
# Role: Testing
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "BIOS";
  form = "Microsoft Azure";
  cpu = "x86_64";
  ram = 1;

  # 2. Storage
  disks = [ "/dev/vda" ];

  # 3. System Profile
  usage = [
    "Server"
    "Password SSH Login"
    "Insecure Setup Password"
  ];
}

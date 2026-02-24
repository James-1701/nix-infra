# Host Manifest: Google Compute Engine VPS
# Role: Testing
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  boot = "BIOS";
  form = "Google Compute Engine";
  cpu = "EPYC 7B12";
  ram = 1;

  # 2. Storage
  disks = [ "/dev/sda" ];

  # 3. System Profile
  usage = [
    "Server"
  ];
}

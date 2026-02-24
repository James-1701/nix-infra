# Host Manifest: Dell Latitude 7370
# Role: Home Server
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  # Note: 'form' strictly implies CPU and RAM.
  boot = "UEFI";
  form = "Dell Latitude 7370";

  # 2. Storage
  disks = [ "/dev/nvme0n1" ];
  storage = [
    "NVMe"
    "SMART"
  ];

  # 3. System Profile
  usage = [
    "n8n"
  ];
}

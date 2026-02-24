# Host Manifest: Acer Predator PH315-52
# Role: Server Hosting / GPU Compute Node
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  # Note: 'form' strictly implies CPU (i7-9750H), GPU (GTX 1660 Ti), and RAM (16GB).
  boot = "UEFI";
  form = "Acer Predator PH315-52";

  # 2. Storage
  disks = [ "/dev/nvme0n1" ];
  storage = [ "NVMe" ];

  # 3. System Profile
  usage = [
    "Nix Remote Builder"
    "Ollama"
  ];
}

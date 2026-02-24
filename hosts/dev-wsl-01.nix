# Host Manifest: NixOS on Windows Subsystem for Linux (WSL)
# Role: Testing / Development
#
# See `hosts/README.md` for schema details.

{
  # 1. Hardware
  form = "WSL";
  cpu = "x86_64";
  ram = 32;
  swap = false;

  # 2. Storage
  # Handled by nixos-wsl (Upstream Reference: https://github.com/nix-community/NixOS-WSL)

  # 3. System Profile
  usage = [
    "Development"
  ];
}

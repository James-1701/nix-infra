# Auto-discovery overlay for custom packages
# Just add a .nix file to the directory and rebuild

final: prev:

let
  inherit (prev) lib;

  # Read all files in the current directory
  dir = builtins.readDir ./.;

  # Filter only .nix files, excluding this default.nix
  validFiles = lib.filterAttrs (
    name: type: type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name
  ) dir;

  # Convert filename to package name (removes .nix extension)
  # Imports each file as a proper Nix package
  packages = lib.mapAttrs' (name: _: {
    name = lib.removeSuffix ".nix" name;
    value = final.callPackage (./. + "/${name}") { };
  }) validFiles;
in
packages

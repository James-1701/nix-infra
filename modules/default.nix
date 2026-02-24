# Main system configuration module
# Integrates home-manager, system packages, and modular nixos configurations
# Uses lineage-based traits system for feature composition

{
  lib,
  config,
  lineage,
  inputs,
  ...
}:

{
  config = lib.mkMerge [
    {
      nixpkgs = {

        # Allow specific insecure packages needed for compatibility
        config.permittedInsecurePackages = [
          "libsoup-2.74.3" # Required for older gnome extensions
          "intel-media-sdk-23.2.2" # Required for hardware acceleration on older intel platforms
        ];

        overlays = [

          # Custom packages from local pkgs directory
          (import ../pkgs)

          # Fixes intel-media-sdk build failure
          # Upstream issue: https://github.com/NixOS/nixpkgs/issues/432403
          (_self: super: {
            intel-media-sdk = super.intel-media-sdk.overrideAttrs (old: {
              cmakeFlags = old.cmakeFlags ++ [ "-DCMAKE_CXX_STANDARD=17" ];
              NIX_CFLAGS_COMPILE = "-std=c++17";
            });
          })
        ];
      };
    }

    # `optionalAttrs` hides this from systems that dont home manager installed and would therefore fail evaluation
    # Non desktop systems don't get home manager unless they run openclaw
    (lib.optionalAttrs (lineage.has.usage "Desktop" || lineage.has.usage "OpenClaw") {
      home-manager = {
        backupFileExtension = "backup";
        useGlobalPkgs = true;
        useUserPackages = true;

        extraSpecialArgs = {
          inherit inputs lineage;
        };

        # Dynamically configures home-manager for each system user
        users = lib.mapAttrs (
          name: user:
          { osConfig, ... }:
          {
            home = {
              inherit (osConfig.system) stateVersion; # Uses the NixOS state version
              homeDirectory = osConfig.users.users.${name}.home;
            };

            # Only import desktop modules for Desktop systems that dont manage configuration declaratively
            # We do this because users with imperative setups would have their configurations overridden
            imports = lib.optionals ((lineage.has.usage "Desktop") && (user.persistence != "full")) (
              map (module: ./home/${module}.nix) [
                "kde"
                "users"
                "gnome"
                "cosmic"
                "desktop"
                "software"
                "applications"
                "virtualization"
              ]
            );
          }
        ) config.internal.users;
      };
    })
  ];

  imports =

    # Imports all the NixOS configuration modules
    map (module: ./nixos/${module}.nix) [
      "kde"
      "core"
      "boot"
      "sops"
      "users"
      "audio"
      "gnome"
      "cosmic"
      "desktop"
      "hosting"
      "graphics"
      "security"
      "software"
      "terminal"
      "printing"
      "platforms"
      "processor"
      "networking"
      "filesystems"
      "performance"
      "development"
      "connectivity"
      "virtualization"
    ]
    ++ [

      # Imports the needed external flake modules
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
      inputs.nixos-wsl.nixosModules.default
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.default
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.impermanence.nixosModules.impermanence
      inputs.nix-index-database.nixosModules.nix-index
    ];
}

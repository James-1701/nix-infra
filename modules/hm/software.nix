{
  pkgs,
  lib,
  config,
  inputs,
  lineage,
  osConfig ? null,
  ...
}:

let
  userConfig = osConfig.internal.users.${config.home.username} or { };

  # Gets the packages
  nixpkgsList = userConfig.packages.nixpkgs or [ ];
  flatpakList = userConfig.packages.flatpaks or [ ];
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];
  config = {

    # installs the specified nixpgks applications for the user
    home.packages = lib.mkIf (nixpkgsList != [ ]) ((names: map (name: pkgs.${name}) names) nixpkgsList);

    # Enables flatpak support for the user, and installs the specified flatpaks
    services.flatpak = lib.mkIf (flatpakList != [ ]) {
      enable = lineage.has.usage "Desktop";
      packages = flatpakList;
    };
  };
}

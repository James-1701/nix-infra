{
  lineage,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "Cosmic") {

    # Enables the "Cosmic" desktop environment
    services = {
      displayManager = {
        defaultSession = "cosmic";
        cosmic-greeter.enable = true;
      };
      desktopManager.cosmic = {
        enable = true;
        xwayland.enable = true;
      };
    };

    # Ensures proper XDG portals are setup
    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal-cosmic
    ];

    # Removes certain packages (I have this here for when I inevitably remove some later)
    environment.cosmic.excludePackages = [ ];
  };
}

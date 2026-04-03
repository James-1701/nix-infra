{
  config,
  pkgs,
  lib,
  osConfig ? null,
  lineage,
  ...
}:

let
  # Allows setting the cursor theme, size, and package in one place for all relevant desktop environments and toolkits.
  cursor = {
    package = pkgs.oreo-cursors-plus;
    name = "oreo_white_cursors";
    size = 16;
  };
in
{
  config = lib.mkIf (lineage.has.usage "Desktop") {

    # General desktop environment settings that apply to all supported environments and toolkits.
    dconf.enable = true;
    qt.enable = true;
    gtk = {
      enable = true;
      cursorTheme = {
        inherit (cursor) package name size;
      };
    };

    # Sets up the cursor icon theme
    home.pointerCursor = {
      enable = true;
      inherit (cursor) package name size;
      sway.enable = true;
      dotIcons.enable = true;
      x11 = {
        enable = true;
        defaultCursor = "left_ptr";
      };
      hyprcursor = {
        enable = true;
        inherit (cursor) size;
      };
    };

    xdg = {
      enable = true;

      # Sets the XDG base directories to the standard locations in the user's home directory.
      dataHome = "${config.home.homeDirectory}/.local/share";
      stateHome = "${config.home.homeDirectory}/.local/state";

      # Configures the MIME types and default applications based on the host system's configuration, if available.
      # This is essentially just which application open which file types.
      mimeApps = {
        enable = true;
        defaultApplications = lib.mkIf (osConfig != null) osConfig.xdg.mime.defaultApplications;
      };

      # Creates and sets all the standard user directories
      userDirs = {
        enable = true;
        createDirectories = true;
        desktop = "${config.home.homeDirectory}/Desktop";
        documents = "${config.home.homeDirectory}/Documents";
        download = "${config.home.homeDirectory}/Downloads";
        music = "${config.home.homeDirectory}/Music";
        pictures = "${config.home.homeDirectory}/Pictures";
        publicShare = "${config.home.homeDirectory}/Public";
        templates = "${config.home.homeDirectory}/Templates";
        videos = "${config.home.homeDirectory}/Videos";
        extraConfig.XDG_MISC_DIR = "${config.home.homeDirectory}/Misc";
      };

      # Configures the XDG portals with the modules from the host system
      portal = {
        enable = true;
        xdgOpenUsePortal = true;
        configPackages = lib.mkIf (osConfig != null) osConfig.xdg.portal.configPackages;
        extraPortals = lib.mkIf (osConfig != null) osConfig.xdg.portal.extraPortals;
        config = lib.mkIf (osConfig != null) osConfig.xdg.portal.config;
      };

      # Setups up XGD autostart applications
      autostart = {
        enable = true;
        readOnly = true;
      };
    };
  };
}

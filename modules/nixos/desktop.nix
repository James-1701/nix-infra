{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

let
  isLaptop = lineage.has.form "Laptop";

  # Browsers are used to open many file types so its easier to set as a variable for consistency
  browser = "firefox-devedition.desktop";
in
{
  config = lib.mkIf (lineage.has.usage "Desktop") {

    # Common desktop frameworks and integration
    qt.enable = true;
    gtk.iconCache.enable = true;
    programs.dconf.enable = true;

    # 2 in 1 devices get iio sensors
    hardware.sensor.iio.enable = lineage.has.form "2-in-1";

    # Sets up proper system font configuration
    fonts = {
      packages = with pkgs; [ nerd-fonts.symbols-only ];
      fontDir.enable = true;
      fontconfig = {
        enable = true;
        antialias = true;
        useEmbeddedBitmaps = true;
        subpixel = {
          rgba = "rgb";
          lcdfilter = "none";
        };
        hinting = {
          enable = true;
          style = "full";
        };
      };
    };

    # Sets up add the needed XDG options and specification for desktop integration
    xdg = {
      autostart.enable = true;
      menus.enable = true;
      icons.enable = true;
      mime = {
        enable = true;
        defaultApplications = {
          "application/pdf" = browser;
          "application/xhtml+xml" = browser;
          "audio/x-vorbis+ogg" = "com.github.neithern.g4music.desktop";
          "text/html" = browser;
          "x-scheme-handler/http" = browser;
          "x-scheme-handler/https" = browser;
          "x-scheme-handler/mailto" = "org.mozilla.Thunderbird.desktop";
        };
      };
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal
        ];
      };
    };

    # Some basic desktop services
    location.provider = lib.mkIf isLaptop "geoclue2";
    services = {
      systembus-notify.enable = true;
      geoclue2 = {
        enable = lib.mkForce isLaptop;
        enableDemoAgent = false;
        submitData = false;
        enableWifi = true;
        enableNmea = true;
        enableModemGPS = true;
        enableCDMA = true;
        enable3G = true;
      };
    };

    # Common directories to persist for a cohesive desktop experience
    environment.persistence."/nix/persist" = {
      directories = [ "/var/lib/systemd/backlight" ];
      users = lib.mapAttrs (_: _: {
        directories = [
          "Misc"
          "Videos"
          "Documents"
          "Pictures"
          "Music"
          "Templates"
          ".mozilla"
        ];
      }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
    };
  };
}

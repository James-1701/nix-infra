{
  pkgs,
  lib,
  inputs,
  lineage,
  ...
}:

{
  # Sets tons of gnome settings for apps, the desktop and the plugins I use
  # I dont use gnome on any systems anymore so this file is semi-unmaintained
  # if I switch back to gnome at a later date ill update and clean this file up,
  # Until then it is 100% functional but not too pretty to look at
  dconf.settings = lib.mkIf (lineage.has.usage "Gnome") {
    "org/gnome/shell" = {
      remember-mount-password = true;
      disable-user-extensions = false;
      disable-extension-version-validation = true;
      enabled-extensions = with pkgs.gnomeExtensions; [
        clipboard-history.extensionUuid
        screen-rotate.extensionUuid
        gsconnect.extensionUuid
        pop-shell-no-icon.extensionUuid
        touchup.extensionUuid
        blur-my-shell.extensionUuid
        quick-settings-audio-panel.extensionUuid
      ];
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Geary.desktop"
        "org.gnome.Calendar.desktop"
        "sh.cider.Cider.desktop"
        "md.obsidian.Obsidian.desktop"
        "dev.zed.Zed.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };
    "org/gnome/settings-daemon/plugins/housekeeping".donation-reminder-enabled = false;
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///var/lib/wallpapers/rowing.jpg";
      picture-uri-dark = "file:///var/lib/wallpapers/rowing.jpg";
    };
    "system/proxy".mode = "manual"; # "none" "auto";
    "org/gnome/system/location" = {
      enabled = true;
      max-accuracy-level = "exact"; # "neighborhood";
    };
    "org/gnome/desktop/datetime".automatic-timezone = true;
    "org/gnome/desktop/privacy" = {
      old-files-age = inputs.home-manager.lib.hm.gvariant.mkUint32 1;
      remove-old-temp-files = true;
      remove-old-trash-files = true;
      remember-recent-files = false;
      remember-app-usage = false;
      hide-identity = true;
      report-technical-problems = lib.mkForce false;
      send-software-usage-stats = lib.mkForce false;
      privacy-screen = true;
    };
    "org/gnome/shell/extensions/just-perfection" = {
      theme = false; # true;
      #        screen-recording-indicator=false;
      #        screen-sharing-indicator=false;
      search = false;
      accessibility-menu = false;
      events-button = true; # false;
      keyboard-layout = false;
      osd = false;
      window-preview-caption = false;
      startup-status = 0;
      workspace-wrap-around = true;
      window-demands-attention-focus = true;
      world-clock = false;
    };
    "org/gnome/shell/extensions/blur-my-shell/applications" = {
      brightness = 1;
      customize = true;
      #       enable-all = true;
      opacity = 217;
    };
    "org/gnome/shell/extensions/blur-my-shell" = {
      #        hacks-level = 3;
      noise-amount = 0.1;
    };
    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      blur = false;
      customize = true;
      sigma = 1;
      brightness = 0.0;
      noise-amount = 0;
      noise-lightness = 1.0;
      #color = mkTuple [ 0.0 0.0 0.0 0.0 ];
      #        static-blur = false;
      #        override-background-dynamically = true;
      #        style-panel = 3;
    };
    "org/gnome/shell/extensions/forge".focus-border-toggle = false;
    "org/gnome/shell/extensions/forge/keybindings" = {
      window-snap-two-third-right = [ ];
      con-split-vertical = [ ];
    };
    "org/gnome/desktop/wm/preferences" = {
      action-middle-click-titlebar = "toggle-shade";
      audible-bell = false;
      auto-raise = true;
      resize-with-right-button = true;
      button-layout = "appmenu: ";
      focus-mode = "sloppy";
      #titlebar-font = "UbuntuMono Nerd Font Bold 11";
    };
    "org/gnome/shell/extensions/touchup".navigation-bar-enabled = false;
    "org/gnome/Weather" = with inputs.home-manager.lib.hm.gvariant; {
      locations = [
        (mkVariant (mkTuple [
          (mkUint32 2)
          (mkVariant (mkTuple [
            "Grand Rapids"
            "KGRR"
            true
            [
              (mkTuple [
                0.74841172184783755
                (-1.4926540615521711)
              ])
            ]
            [
              (mkTuple [
                0.74985208971963102
                (-1.495190164581659)
              ])
            ]
          ]))
        ]))
      ];
    };
    "org/gnome/shell/weather" = with inputs.home-manager.lib.hm.gvariant; {
      automatic-location = true;
      locations = [
        (mkVariant (mkTuple [
          (mkUint32 2)
          (mkVariant (mkTuple [
            "Grand Rapids"
            "KGRR"
            true
            [
              (mkTuple [
                0.74841172184783755
                (-1.4926540615521711)
              ])
            ]
            [
              (mkTuple [
                0.74985208971963102
                (-1.495190164581659)
              ])
            ]
          ]))
        ]))
      ];
    };
    "org/gnome/gnome-session".auto-save-session = true;
    "org/gnome/desktop/notifications".show-in-lock-screen = false;
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
      center-new-windows = true;
      workspaces-only-on-primary = false;
      edge-tiling = true;
      experimental-features = [
        "hdr-enabled"
        "variable-refresh-rate"
        "autoclose-xwayland"
        "kms-modifiers"
      ]; # "scale-monitor-framebuffer" ];
    };
    "org/gnome/desktop/sound".event-sounds = false;
    "org/gnome/shell/app-switcher".current-workspace-only = true;
    "org/gnome/settings-daemon/plugins/wwan".unlock-sim = true;
    "org/gnome/settings-daemon/plugins/color".night-light-enabled = false;
    "org/gnome/shell/extensions/gsconnect".enabled = false;
    "org/gnome/shell/extensions/dash-to-dock" = {
      click-action = "focus-or-previews";
      customize-alphas = true;
      dash-max-icon-size = 64;
      dock-fixed = false;
      extend-height = false;
      hide-tooltip = true;
      icon-size-fixed = true;
      isolate-monitors = false;
      running-indicator-dominant-color = true;
      running-indicator-style = "DOTS";
      scroll-action = "cycle-windows";
      scroll-to-focused-application = true;
      show-mounts = false;
      show-show-apps-button = false;
      show-trash = false;
      transparency-mode = "FIXED";
      background-opacity = 0.1;
      custom-background-color = true;
      background-color = "rgb(255,255,255)";
      intellihide = false;
      autohide = false;
    };
    "org/gnome/desktop/app-folders/folders/ee205a42-feab-45ec-b5fd-62f13b24ca67" = {
      apps = [
        "gnome-abrt.desktop"
        "gnome-system-log.desktop"
        "nm-connection-editor.desktop"
        "org.gnome.baobab.desktop"
        "org.gnome.Connections.desktop"
        "org.gnome.DejaDup.desktop"
        "org.gnome.Dictionary.desktop"
        "org.gnome.DiskUtility.desktop"
        "org.gnome.Evince.desktop"
        "org.gnome.FileRoller.desktop"
        "org.gnome.fonts.desktop"
        "org.gnome.Loupe.desktop"
        "org.gnome.seahorse.Application.desktop"
        "org.gnome.tweaks.desktop"
        "org.gnome.Usage.desktop"
        "vinagre.desktop"
        "org.gnome.Firmware.desktop"
        "com.github.tchx84.Flatseal.desktop"
        "ca.desrt.dconf-editor.desktop"
        "org.rnd2.cpupower_gui.desktop"
        "io.github.Foldex.AdwSteamGtk.desktop"
        "hu.irl.cameractrls.desktop"
        "com.github.wwmm.easyeffects.desktop"
        "org.gnome.Extensions.desktop"
        "org.pipewire.Helvum.desktop"
        "org.bluesabre.MenuLibre.desktop"
        "org.wireshark.Wireshark.desktop"
        "opensnitch_ui.desktop"
        "com.usebottles.bottles.desktop"
        "org.pulseaudio.pavucontrol.desktop"
        "org.kde.krusader.desktop"
        "com.github.rafostar.Clapper.desktop"
        "io.gitlab.daikhan.stable.desktop"
        "org.ardour.Ardour.desktop"
        "org.gnome.Geary.desktop"
        "com.getmailspring.Mailspring.desktop"
        "org.gnome.Evolution.desktop"
        "org.gnome.Logs.desktop"
      ];
      name = "Stuff";
      translate = true;
    };
    "org/gnome/desktop/app-folders/folders/e6f36f1d-37cb-4491-a4fc-226004d41c4c" = {
      apps = [
        "org.libreoffice.LibreOffice.desktop"
        "org.libreoffice.LibreOffice.writer.desktop"
        "org.libreoffice.LibreOffice.calc.desktop"
        "org.libreoffice.LibreOffice.draw.desktop"
        "org.libreoffice.LibreOffice.impress.desktop"
        "org.libreoffice.LibreOffice.math.desktop"
      ];
      name = "Office";
    };
    "org/gnome/shell/extensions/pano" = {
      global-shortcut = [ "<super>v" ];
      history-length = 500;
      sync-primary = true;
      incognito-shortcut = [ "<Alt><Super>v" ];
      keep-search-entry = false;
      show-indicator = false;
      paste-on-select = false;
      play-audio-on-copy = false;
      send-notification-on-copy = false;
    };
    "org/gnome/shell/extensions/blur-my-shell/overview".style-components = 2;
    "org/gnome/shell/extensions/clipboard-history" = {
      disable-down-arrow = true;
      display-mode = 3;
      notify-on-copy = false;
      strip-text = false;
      paste-on-selection = false;
      process-primary-selection = false;
      toggle-menu = [ "<Super>v" ];
    };
    "org/gnome/nautilus/list-view".use-tree-view = true;
    "org/gnome/nautilus/preferences" = {
      show-create-link = true;
      show-delete-permanently = true;
    };
    "org/gnome/shell/extensions/libpanel" = {
      layout = [
        [
          "gnome@main"
          "quick-settings-audio-panel@rayzeq.github.io/main"
        ]
      ];
      column-spacing-enabled = false;
      row-spacing-enabled = false;
      padding-enabled = false;
    };
    "org/gnome/shell/extensions/quick-settings-audio-panel" = {
      master-volume-sliders-show-current-device = true;
      create-applications-volume-sliders = true;
      group-applications-volume-sliders = false;
      always-show-input-volume-slider = true;
      ignore-virtual-capture-streams = false;
      mpris-controllers-are-moved = true;
      autohide-profile-switcher = true;
      move-output-volume-slider = true;
      create-mpris-controllers = false;
      move-input-volume-slider = true;
      create-profile-switcher = false;
      panel-type = "merged-panel";
      merged-panel-position = "top";
      pactl-path = "${pkgs.pulseaudio}/bin/pactl";
      widgets-order = [
        "mpris-controllers"
        "profile-switcher"
        "output-volume-slider"
        "applications-volume-sliders"
        "perdevice-volume-sliders"
        "balance-slider"
        "input-volume-slider"
      ];
      version = 2;
    };
    "org/gnome/shell/extensions/pop-shell" = {
      smart-gaps = true;
      tile-by-default = true;
    };
    "org/gnome/shell/extensions/paperwm" = {
      #default-focus-mode = 1;
      use-default-background = true;
      show-workspace-indicator = false;
      gesture-workspace-fingers = 0;
      gesture-horizontal-fingers = 4;
      restore-attach-modal-dialogs = false;
      restore-edge-tiling = true;
      restore-keybinds = ''
        {"toggle-tiled-right":{"bind":"[\\"<Super>Right\\"]","schema_id":"org.gnome.mutter.keybindings"},"cancel-input-capture":{"bind":"[\\"<Super><Shift>Escape\\"]","schema_id":"org.gnome.mutter.keybindings"},"toggle-tiled-left":{"bind":"[\\"<Super>Left\\"]","schema_id":"org.gnome.mutter.keybindings"},"restore-shortcuts":{"bind":"[\\"<Super>Escape\\"]","schema_id":"org.gnome.mutter.wayland.keybindings"},"switch-to-workspace-last":{"bind":"[\\"<Super>End\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-applications":{"bind":"[\\"<Super>Tab\\",\\"<Alt>Tab\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-to-workspace-left":{"bind":"[\\"<Super>Page_Up\\",\\"<Super><Alt>Left\\",\\"<Control><Alt>Left\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"move-to-monitor-down":{"bind":"[\\"<Super><Shift>Down\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-applications-backward":{"bind":"[\\"<Shift><Super>Tab\\",\\"<Shift><Alt>Tab\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-to-workspace-1":{"bind":"[\\"<Super>Home\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-to-workspace-right":{"bind":"[\\"<Super>Page_Down\\",\\"<Super><Alt>Right\\",\\"<Control><Alt>Right\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"maximize":{"bind":"[\\"<Super>Up\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-group-backward":{"bind":"[\\"<Shift><Super>Above_Tab\\",\\"<Shift><Alt>Above_Tab\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"move-to-monitor-right":{"bind":"[\\"<Super><Shift>Right\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"move-to-monitor-left":{"bind":"[\\"<Super><Shift>Left\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"move-to-monitor-up":{"bind":"[\\"<Super><Shift>Up\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"unmaximize":{"bind":"[\\"<Super>Down\\",\\"<Alt>F5\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"switch-group":{"bind":"[\\"<Super>Above_Tab\\",\\"<Alt>Above_Tab\\"]","schema_id":"org.gnome.desktop.wm.keybindings"},"shift-overview-down":{"bind":"[\\"<Super><Alt>Down\\"]","schema_id":"org.gnome.shell.keybindings"},"focus-active-notification":{"bind":"[\\"<Super>n\\"]","schema_id":"org.gnome.shell.keybindings"},"shift-overview-up":{"bind":"[\\"<Super><Alt>Up\\"]","schema_id":"org.gnome.shell.keybindings"},"rotate-video-lock-static":{"bind":"[\\"<Super>o\\",\\"XF86RotationLockToggle\\"]","schema_id":"org.gnome.settings-daemon.plugins.media-keys"}}
      '';
      restore-workspaces-only-on-primary = false;
      show-window-position-bar = false;
    };
    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
      clock-show-weekday = true;
      #font-antialiasing = "none";
      #font-hinting = "none"; # "full";
      #font-name = config.stylix.fonts.monospace.name;
      gtk-enable-primary-paste = false;
      color-scheme = lib.mkDefault "prefer-dark";
    };
    "org/gnome/desktop/input-sources" = {
      show-all-sources = true;
      #sources = [( "xkb" "us" )];
      xkb-options = [
        "caps:hyper"
        "compose:menu"
      ];
    };
    "org/gnome/desktop/peripherals/mouse".accel-profile = "flat";
    "org/gnome/desktop/peripherals/touchpad" = {
      click-method = "fingers";
      # disable-while-typing = false;
      send-events = "enabled";
      tap-to-click = true;
    };
    "org/gnome/desktop/calendar".show-weekdate = true;
    "org/gnome/shell/keybindings" = {
      show-screenshot-ui = [
        "Print"
        "<Shift><Super>s"
      ];
      screenshot-window = [
        "<Alt>Print"
        "<Alt>F11"
      ];
      screenshot = [
        "<Shift>Print"
        "<Shift>F11"
      ];
      toggle-message-tray = [ "<Super>m" ];
    };
    "org/gnome/desktop/wm/keybindings" = {
      close = [
        "<Alt>F4"
        "<Super>q"
      ];
      toggle-fullscreen = [ "F11" ];
    };
    "org/gnome/mutter/keybindings".switch-monitor = [ ];
    "org/gnome/settings-daemon/plugins/media-keys" = {
      home = [ "<Super>e" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Control><Alt>t";
      command = "${pkgs.gnome-console}/bin/kgx --tab";
      name = "Terminal";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Shift><Control>Escape";
      command = "${pkgs.gnome-usage}/bin/gnome-usage";
      name = "Task Manager";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>P";
      command = "${pkgs.flatpak}/bin/flatpak run org.gnome.NetworkDisplays";
      name = "Screen Cast";
    };
  };
}

{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "Gnome") {

    # Installs the gnome extension version of kdeconnect
    programs.kdeconnect = {
      enable = true;
      package = pkgs.gnomeExtensions.gsconnect;
    };

    services = {
      desktopManager.gnome.enable = true;

      # Tools that gnome uses
      udisks2.enable = lib.mkForce true;
      udev.packages = [ pkgs.gnome-settings-daemon ];
      gvfs = {
        enable = true;
        package = pkgs.gnome.gvfs;
      };
      gnome = {

        # Enables just all the needed components
        gnome-online-accounts.enable = true;
        gnome-remote-desktop.enable = true;
        gnome-initial-setup.enable = false;
        core-apps.enable = false;
        sushi.enable = false;
      };

      # Login screen setup
      displayManager = {
        defaultSession = "gnome";
        gdm = {
          enable = true;
          settings.daemon.FirstVT = 3; # I dont think this works but I would like to look into it later
        };
      };
    };

    # Installs needed portals
    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];

    environment = {
      systemPackages =
        (with pkgs; [
          adwaita-icon-theme
          gnome.gvfs
          gvfs
        ])
        ++ (with pkgs.gnomeExtensions; [

          # Some extensions I used to use
          #
          #clipboard-history
          #vertical-workspaces
          #another-window-session-manager
          #appindicator
          #dim-background-windows
          #just-perfection
          #forge
          #undecorate
          #dash-to-dock
          #paperwm

          # Current Extensions
          clipboard-history
          quick-settings-audio-panel
          screen-rotate
          pop-shell-no-icon
          blur-my-shell
          touchup
        ]);

      # Gnome software not to include
      gnome.excludePackages = with pkgs; [
        gnome-software
        gnome-tour
      ];

      # Persists some gnome and gnome app specific directories
      persistence."/nix/persist".users = lib.mapAttrs (_: _: {
        directories = [
          ".config/goa-1.0"
          ".config/evolution/sources"
          ".cache/evolution/sources"
          ".cache/evolution/calendar"
          ".local/share/gnome-shell"
          ".local/share/keyrings"
          ".local/share/evolution/calendar"
        ];
      }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
    };

    nixpkgs.overlays = [

      # Hides the pop-shell icon in the top bar
      (_final: prev: {
        gnomeExtensions = prev.gnomeExtensions // {
          pop-shell-no-icon = prev.gnomeExtensions.pop-shell.overrideAttrs (oldAttrs: {
            postInstall = ''
              ${oldAttrs.postInstall or ""}
              substituteInPlace $out/share/gnome-shell/extensions/pop-shell@system76.com/extension.js \
                --replace "panel.addToStatusArea('pop-shell', indicator.button);" "// panel.addToStatusArea('pop-shell', indicator.button);"
            '';
          });
        };
      })

      # Hides the Extensions app because they are managed declaratively
      (_final: prev: {
        gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
          postInstall = (oldAttrs.postInstall or "") + ''
            substituteInPlace $out/share/applications/org.gnome.Extensions.desktop \
              --replace "OnlyShowIn=GNOME;" "NoDisplay=true"
          '';
        });
      })

      # Enables Google Drive nautilus support
      (_final: prev: {
        gnome = prev.gnome.overrideScope (
          _gfinal: gprev: {
            gvfs = gprev.gvfs.override {
              googleSupport = true;
              gnomeSupport = true;
            };
          }
        );
      })
    ];
  };
}

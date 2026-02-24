{
  config,
  pkgs,
  lib,
  lineage,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "Desktop") {

    # Sets up appimage support and creates a binfmt rule to run them by default
    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    # Enables flatpaks & updates
    services.flatpak = {
      enable = true;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };

      # Sets up the flatpaks defined in the hostfile
      packages = lineage.traits.packages.flatpaks or [ ];

      # Ensures flatpaks can get items from the nix store (Fixes many issues with flatpaks on NixOS)
      overrides.global.Context.filesystems = [ "/nix/store:ro" ];

      # Adds common flatpak remotes
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
        {
          name = "flathub-beta";
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
        {
          name = "gnome-nightly";
          location = "https://nightly.gnome.org/gnome-nightly.flatpakrepo";
        }
      ];
    };

    # Helps to fix flatpak icon and font issues
    system.fsPackages = [ pkgs.bindfs ];
    fileSystems =
      let

        # Creates a helper for making read-only bindings
        mkRoSymBind = path: {
          device = path;
          fsType = "fuse.bindfs";
          options = [
            "ro"
            "resolve-symlinks"
            "x-gvfs-hide"
          ];
        };

        # Gets all the fonts and icons
        aggregatedFonts = pkgs.buildEnv {
          name = "system-fonts-and-icons";
          paths = config.fonts.packages;
          pathsToLink = [
            "/share/fonts"
            "/share/icons"
          ];
        };
      in
      {
        # Adds icons and fonts to standard paths
        "/usr/share/icons" = mkRoSymBind "${aggregatedFonts}/share/icons";
        "/usr/share/fonts" = mkRoSymBind "${aggregatedFonts}/share/fonts";
      }

      # Binds the firefox native and flatpak packages to the same configuration
      // (builtins.listToAttrs (
        lib.mapAttrsToList (name: user: {
          name = "/home/${name}/.var/app/org.mozilla.firefox/.mozilla";
          value = lib.mkIf (user.persistence == "default") {
            device = "/home/${name}/.mozilla";
            fsType = "none";
            options = [ "bind" ];
          };
        }) config.internal.users
      ));

    environment = {

      # Installs the system packages from the hostfile
      systemPackages = (names: map (name: pkgs.${name}) names) (lineage.traits.packages.nixpkgs or [ ]);

      # Persists the flatpak installation directories
      persistence."/nix/persist" = {
        directories = [ "/var/lib/flatpak" ];
        users = lib.mapAttrs (_: user: {
          directories =
            lib.mkIf ((user.persistence == "default") && ((user.packages.flatpaks or [ ]) != [ ]))
              [
                ".var/app"
                ".local/share/flatpak"
              ];
        }) config.internal.users;
      };
    };
  };
}

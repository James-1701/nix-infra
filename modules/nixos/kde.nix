{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "KDE") (
    lib.mkMerge [
      {
        # Enables the KDE Plasma desktop environment
        services = {
          desktopManager.plasma6.enable = true;
          displayManager = {
            defaultSession = "plasma";
            sddm = {
              enable = true;
              wayland.enable = true;
            };
          };
        };

        programs.kdeconnect.enable = true;

        # Ensures XDG portals are correctly setup
        xdg.portal.extraPortals = with pkgs; [
          kdePackages.xdg-desktop-portal-kde
        ];

        environment = {

          # Some packages to add to the KDE environment
          systemPackages = with pkgs; [
            kdePackages.krohnkite
            maliit-keyboard
            maliit-framework
          ];

          # KDE packages to remove from the system
          plasma6.excludePackages = with pkgs.kdePackages; [
            plasma-browser-integration
            plasma-integration
            plasma-workspace
            baloo-widgets
            kcoreaddons
            khelpcenter
            kguiaddons
            gwenview
            oxygen
            okular
            baloo
            elisa
            kate
          ];

          # Persists KDE Wallet
          persistence."/nix/persist".users = lib.mapAttrs (_: _: {
            directories = [ ".local/share/kwalletd" ];
          }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
        };
      }

      # AeroThemePlasma is a theme to make KDE Plasma look like the Windows 7 Shell
      # Because this is just an aesthetic theme this is pretty low priority for me to work on more
      (lib.mkIf (lineage.has.usage "AeroThemePlasma") {
        environment.systemPackages = [ pkgs.aerothemeplasma.theme ];
        qt.style = "kvantum";
      })
    ]
  );
}

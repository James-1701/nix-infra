{
  inputs,
  lineage,
  config,
  lib,
  ...
}:

let
  useKDE = lineage.has.usage "KDE";

  wallpaper = "/var/lib/wallpapers/rowing.jpg";
in
{
  # Plasma manager is needed to configure KDE Plasma declatively
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  config = lib.mkIf useKDE (
    lib.mkMerge [
      {
        # General Plasma configuration, applied regardless of theme
        # This uses many sane defaults and is a good starting point for further customization
        programs.plasma = {
          enable = true;
          overrideConfig = true;
          session.sessionRestore.restoreOpenApplicationsOnLogin = "onLastLogout";
          windows.allowWindowsToRememberPositions = true;
          workspace = {
            inherit wallpaper;
            enableMiddleClickPaste = true;
            clickItemTo = "select";
            splashScreen.theme = "None";
          };
          kwin.effects = {
            minimization.animation = "magiclamp";
            wobblyWindows.enable = true;
            dimAdminMode.enable = true;
            shakeCursor.enable = true;
            dimInactive.enable = true;
            blur.enable = true;
          };
          configFile = {
            kcminputrc = {
              "Mouse" = {
                "cursorSize" = config.home.pointerCursor.size;
                "cursorTheme" = config.home.pointerCursor.name;
              };
              "Libinput/1267/12554/ELAN07CD:00 04F3:310A Touchpad" = {
                ClickMethod = 2;
                NaturalScroll = true;
              };
            };
            "KDE/Sonnet.conf" = {
              General = {
                autodetectLanguage = true;
                backgroundCheckerEnabled = true;
                checkUppercase = true;
                checkerEnabledByDefault = true;
                defaultClient = "";
                defaultLanguage = "en_US";
                ignore_en_US = "Amarok, KAddressBook, KDevelop, KHTML, KIO, KJS, KMail, KMix, KOrganizer, Konqueror, Kontact, Nepomuk, Okular, Qt, Sonnet";
                preferredLanguages = "@Invalid()";
                skipRunTogether = true;
              };
            };
            kwalletrc.Wallet = {
              "Enabled" = true;
              "Leave Open" = true;
              "First Use" = false;
              "Prompt on Open" = false;
              "Close When Idle" = false;
              "Default Wallet" = "Default";
            };
            kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General" = {
              Image = "file://${wallpaper}";
              PreviewImage = "file://${wallpaper}";
            };
            kwinrc = {
              Plugins.krohnkiteEnabled = true;
              Xwayland.Scale = 1.5;
              TouchEdges = {
                Left = "ApplicationLauncher";
                Right = "ShowDesktop";
                Top = "LockScreen";
              };
              Desktops = {
                Id_1 = "Desktop_1";
                Id_2 = "Desktop_2";
                Id_3 = "Desktop_3";
                Id_4 = "Desktop_4";
                Id_5 = "Desktop_5";
                Id_6 = "Desktop_6";
                Id_7 = "Desktop_7";
                Id_8 = "Desktop_8";
                Id_9 = "Desktop_9";
                Number = 9;
                Rows = 3;
              };
              Effect-slide = {
                SlideBackground = false;
                HorizontalGap = 0;
                VerticalGap = 0;
              };
              Effect-wobblywindows = {
                AdvancedMode = true;
                Drag = 60;
                MoveFactor = 20;
              };
              ElectricBorders = {
                BottomLeft = "ApplicationLauncher";
                BottomRight = "ShowDesktop";
              };
              Plugins = {
                contrastEnabled = true;
                hidecursorEnabled = true;
                screenedgeEnabled = false;
                zoomEnabled = false;
              };
              Effect-overview.GridTouchBorderActivate = 4;
              Effect-hidecursor.InactivityDuration = 3;
              Windows.RollOverDesktops = true;
            };
            plasmaparc.General = {
              AudioFeedback = false;
              GlobalMute = true;
              RaiseMaximumVolume = true;
            };
          };
        };
      }

      # This is an example of a theme-specific configuration, applied only if the "AeroThemePlasma" usage is present in the lineage
      # Currently I am not using it but once I can get all the packages from it to build I will switch over to this theme
      (lib.mkIf (lineage.has.usage "AeroThemePlasma") {
        home.file.".config/Kvantum/kvantum.kvconfig".text = ''
          [General]
          theme=Windows7Aero
        '';
        programs.plasma = {
          workspace = {
            iconTheme = "Windows 7 Aero";
            wallpaper = lib.mkForce /var/lib/wallpapers/win7.jpg;
            theme = "Seven-Black";
          };
          panels = [
            {
              floating = false;
              location = "bottom";
              widgets = [
                "io.gitgud.wackyideas.SevenStart"
                "org.kde.plasma.pager"
                "org.kde.plasma.icontasks"
                "org.kde.plasma.marginsseparator"
                "org.kde.plasma.systemtray"
                "io.gitgud.wackyideas.digitalclocklite"
                "io.gitgud.wackyideas.win7showdesktop"
              ];
            }
          ];
          configFile = {
            "kdeglobals" = {
              "KDE"."widgetStyle" = "kvantum";
              "Icons"."Theme" = "Windows 7 Aero";
              "Sounds"."Theme" = "Windows 7";
            };
            "plasmaparc"."Theme"."name" = "Seven-Black";
          };
        };
      })
    ]
  );
}

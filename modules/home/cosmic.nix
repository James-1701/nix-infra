{
  cosmicLib,
  lineage,
  inputs,
  lib,
  ...
}:

let
  useCosmic = lineage.has.usage "Cosmic";
in
{
  # Cosmic manager is needed to configure Cosmic declatively
  imports = lib.optionals useCosmic [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
  ];

  # Cosmic is still in early development so this was mostly just a prototype experiment to try using it
  # If/when i ever switch to Cosmic I will overhaul this, but in the meantime ill keep it here as a baseline to get something working if ever needed
  # This is currently broken for systems that dont have "Cosmic" usage (due to `lib.optionals useCosmic`), so optionalAttrs just ignores it for those systems
  config = lib.optionalAttrs useCosmic {
    wayland.desktopManager.cosmic = {
      enable = true;
      resetFiles = true;
      # panels = [{
      #   name = "Panel";
      #   expand_to_edges = false;
      #   plugins_center = cosmicLib.cosmic.mkRON "optional" [
      #     "com.system76.CosmicAppletTime"
      #   ];
      #   plugins_wings = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "tuple" [
      #     [
      #     ]
      #     [
      #       "com.system76.CosmicAppletStatusArea"
      #       "com.system76.CosmicAppletTiling"
      #       "com.system76.CosmicAppletAudio"
      #       "com.system76.CosmicAppletBluetooth"
      #       "com.system76.CosmicAppletNetwork"
      #       "com.system76.CosmicAppletBattery"
      #       "com.system76.CosmicAppletNotifications"
      #       "com.system76.CosmicAppletPower"
      #     ]
      #   ]);
      #   #size = "S";
      # }];
      applets = {
        audio.settings.show_media_controls_in_top_panel = true;
        time.settings.military_time = true;
      };
      compositor = {
        autotile = true;
        autotile_behavior = cosmicLib.cosmic.mkRON "enum" "PerWorkspace";
        focus_follows_cursor = true;
        descale_xwayland = true;
        workspaces = {
          workspace_layout = cosmicLib.cosmic.mkRON "enum" "Horizontal";
          workspace_mode = cosmicLib.cosmic.mkRON "enum" "OutputBound";
        };
        input_touchpad = {
          click_method = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "Clickfinger");
          disable_while_typing = cosmicLib.cosmic.mkRON "optional" true;
          tap_config = cosmicLib.cosmic.mkRON "optional" {
            button_map = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "LeftMiddleRight");
            drag = true;
            drag_lock = true;
            enabled = true;
          };
          scroll_config = cosmicLib.cosmic.mkRON "optional" {
            method = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "TwoFinger");
            natural_scroll = cosmicLib.cosmic.mkRON "optional" false;
            scroll_button = cosmicLib.cosmic.mkRON "optional" 2;
            scroll_factor = cosmicLib.cosmic.mkRON "optional" 1.0;
          };
        };
      };
      appearance.toolkit = rec {
        size = cosmicLib.cosmic.mkRON "enum" "Spacious";
        interface_density = size;
        header_size = size;
        apply_theme_global = true;
      };
      shortcuts = [
        # {
        #   action = cosmicLib.cosmic.mkRON "enum" "WindowSwitcher";
        #   key = "Super+p";
        # }
        {
          action = cosmicLib.cosmic.mkRON "enum" {
            value = [
              (cosmicLib.cosmic.mkRON "enum" "Terminal")
            ];
            variant = "System";
          };
          key = "Ctrl+Alt+t";
        }
        {
          action = cosmicLib.cosmic.mkRON "enum" {
            value = [
              (cosmicLib.cosmic.mkRON "enum" "Screenshot")
            ];
            variant = "System";
          };
          key = "Super+Shift+s";
        }
      ];
    };
  };
}

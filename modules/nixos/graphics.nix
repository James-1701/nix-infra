{
  pkgs,
  lib,
  config,
  lineage,
  ...
}:

let
  isDesktop = lineage.has.usage "Desktop";
  isWayland = lineage.has.usage "Wayland";
  isIntel = lineage.has.gpu "Intel";
  isNvidia = lineage.has.gpu "Nvidia";

  # Gets the Intel Graphics generation
  intelGraphicsGen = lib.pipe (lineage.traits.gpu or [ ]) [
    (lib.findFirst (str: lib.hasInfix "Gen" str) null)
    (genTrait: if genTrait != null then lib.removePrefix "Gen" genTrait else null)
  ];
in
{
  config = lib.mkMerge [
    {
      boot = {
        kernelModules = lib.optionals isNvidia [ "nvidia" ];
        initrd.kernelModules = lib.optionals isIntel [ "i915" ];
        extraModprobeConfig = lib.mkMerge [
          (lib.mkIf (intelGraphicsGen == 9) "options i915 enable_guc=3") # This generation supports "enable_guc=3"
        ];
      };
    }

    (lib.mkIf isDesktop {
      programs.xwayland.enable = isWayland;

      services.xserver = {
        enable = lineage.has.usage "X11";
        exportConfiguration = true;
        config = pkgs.lib.mkAfter ''
          Section "ServerFlags"
            Option “DontVTSwitch” “true”
          EndSection
        '';
        excludePackages = with pkgs; [ xterm ];
      };
    })

    (lib.mkIf (lineage.has.usage "Graphics") {
      services.xserver.videoDrivers =
        (lib.optionals isIntel [ "modesetting" ]) ++ (lib.optionals isNvidia [ "nvidia" ]);

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages =
            with pkgs;
            [
              # Generic drivers for most linux desktop systems
              libva-vdpau-driver
              libvdpau-va-gl
            ]

            # The following sets the proper intel graphics drivers
            # We use lib.versionAtLeast instead of standard comparison operators,
            # this is because there is no way to convert strings to floats for many of the intel generation values
            ++ lib.optionals isIntel (
              if lib.versionAtLeast intelGraphicsGen "12" then
                [
                  vpl-gpu-rt
                  intel-media-driver
                  intel-compute-runtime
                ]
              else if lib.versionAtLeast intelGraphicsGen "8" then
                [
                  intel-media-sdk
                  intel-media-driver
                  intel-compute-runtime-legacy1
                ]
              else
                [
                  intel-vaapi-driver
                  intel-ocl
                ]
            );

          # Installs some of the 32-bit drivers too
          extraPackages32 = with pkgs.pkgsi686Linux; [
            libva-vdpau-driver
            libvdpau-va-gl
          ];
        };

        # Enables Nvidia GPUs with proper settings
        nvidia = lib.mkIf isNvidia {
          open = true;
          nvidiaSettings = false;
          modesetting.enable = true;
          package = config.boot.kernelPackages.nvidiaPackages.production;
          powerManagement.enable = true;
        };
      };

      environment = {
        systemPackages = lib.optionals isIntel [ pkgs.intel-gpu-tools ];

        # Sets up proper environment variables for wayland use and hardware acceleration
        variables = lib.mkMerge [
          { VAAPI_MPEG4_ENABLED = "true"; }
          (lib.mkIf isWayland {
            NIXOS_OZONE_WL = "1";
          })
          (lib.mkIf isIntel {
            LIBVA_DRIVER_NAME = if lib.versionAtLeast intelGraphicsGen "8" then "iHD" else "i915";
            VDPAU_DRIVER = "va_gl";
            ANV_VIDEO_DECODE = "1";
          })
        ];
      };
    })
  ];
}

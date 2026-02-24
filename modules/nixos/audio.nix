{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "Desktop") {

    # These modules are for DAWs (Digital Audio Workstations) from back when I did more music production
    # Keeping these around doesn't hurt and gives my the flexibility to use the software without messing with kernel modules
    boot.kernelModules = [
      "snd-seq"
      "snd-rawmidi"
    ];

    # Needed for pipewire and realtime audio
    security.rtkit.enable = true;

    services = {

      # Pipewire is the modern linux audio stack
      pipewire = {
        enable = true;
        socketActivation = true;
        audio.enable = true;
        systemWide = false;
        package = pkgs.pipewire;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        jack.enable = true;
        wireplumber = {
          enable = true;
          package = pkgs.wireplumber;
        };
      };
      pulseaudio = {
        enable = false;
        daemon.config.realtime-scheduling = "yes";
      };
    };

    environment = {

      # This ensures that users with "default" persistence have audio settings saved across boots
      persistence."/nix/persist".users = lib.mapAttrs (_: user: {
        directories = lib.mkIf (user.persistence == "default") [
          ".local/state/wireplumber"
        ];
      }) config.internal.users;

      # This helps to give better performing and more stable 3D audio
      etc."openal/alsoftrc.conf".text = ''
        dsp_slow_cpu 1
        snd_spatialize_roundrobin 1
        dsp_enhance_stereo 0
        snd_pitchquality 1
      '';
    };
  };
}

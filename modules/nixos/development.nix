{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkIf (lineage.has.usage "Development") {

    # Docker support
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
      storageDriver = "zfs";
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    # Sets up direnv, which I use in almost all my projects
    programs.direnv = {
      enable = true;
      loadInNixShell = true;
      nix-direnv.enable = true;
    };

    environment = {
      systemPackages = with pkgs; [

        # I use devenv to manage all my projects, it makes dev workflows on nix much more simple and flexible
        devenv

        # IDEs
        zed-editor # Main editor
        windsurf # AI editor built on VS Code
        jetbrains-toolbox # Jetbrains editors are very powerful and are what the school has us use

        # useful CLI tools
        ripgrep
        bat

        # AI Tools
        # Havent figured out my favorite(s) yet
        lmstudio

        plandex
        amp-cli
        goose-cli
        qwen-code
        aider-chat-full
        gemini-cli-bin
        github-copilot-cli
      ];

      # Persists my editors configs (I dont have VS here because I rarely use it)
      persistence."/nix/persist".users = lib.mapAttrs (_: _: {
        directories = [
          # AIs
          ".gemini"
          ".lmstudio"

          # IDEs
          ".config/zed/"
          ".local/share/zed"
          ".local/share/JetBrains"

          # Direnv
          ".local/share/direnv"
          ".cache/direnv"
        ];
        files = [ ".config/github-copilot/apps.json" ];
      }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
    };
  };
}

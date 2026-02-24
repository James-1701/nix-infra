{
  lineage,
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkMerge [
    {
      # Sets up the main SOPS config
      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;
        defaultSopsFormat = "yaml";
        age = {
          sshKeyPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];
          generateKey = true;
        };

        # Decrypts the secrets for use in the system
        secrets = {
          primary-user-password.neededForUsers = true;
          tailscale-auth-key = {
            owner = "root";
            mode = "0400";
          };
        };
      };

      # Persist the sops key so its not wiped and secrets are only recoverable by reading host SSH keys
      environment.persistence."/nix/persist".users = lib.mapAttrs (_: _: {
        directories = [ ".config/sops/age" ];
      }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
    }

    (lib.mkIf (lineage.has.usage "Nextcloud") {
      sops.secrets.nextcloud-admin-password = {
        owner = "nextcloud";
        group = "nextcloud";
      };
    })

    (lib.mkIf (lineage.has.usage "Edge Proxy") {
      sops = {
        secrets.CLOUDFLARE_DNS_API_TOKEN = { };
        templates."acme-env" = {
          content = "CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.CLOUDFLARE_DNS_API_TOKEN}";
          owner = "acme";
        };
      };
    })

    (lib.mkIf (lineage.has.usage "Desktop") {

      # Decrypts the wallpapers for desktops
      sops.secrets."wallpapers.tar" = {
        sopsFile = ../../secrets/wallpapers.tar.enc;
        format = "binary";
        restartUnits = [ "restore-wallpapers.service" ];
      };

      # Exposes wallpapers to /var/lib/wallpapers
      systemd.services."restore-wallpapers" = {
        description = "Extract wallpaper secrets to a usable directory";
        wantedBy = [ "multi-user.target" ];

        serviceConfig.Type = "oneshot";

        script = ''
          SECRET_PATH="${config.sops.secrets."wallpapers.tar".path}"
          TARGET_DIR="/var/lib/wallpapers"

          mkdir -p $TARGET_DIR

          ${pkgs.gnutar}/bin/tar -xf $SECRET_PATH -C $TARGET_DIR --strip-components=1

          chown -R root:users $TARGET_DIR
          chmod -R u=rwX,go=rX $TARGET_DIR
        '';
      };
    })

    # (lib.mkIf (lineage.has.usage "OpenClaw") {
    #   sops =
    #     let
    #       apiKeys = [
    #         "OPENCLAW_GATEWAY_TOKEN"
    #         "DISCORD_BOT_TOKEN"
    #         "GEMINI_API_KEY"
    #         "GROQ_API_KEY"
    #         "MISTRAL_API_KEY"
    #         "OPENROUTER_API_KEY"
    #       ];
    #     in
    #     {
    #       secrets = builtins.listToAttrs (
    #         map (name: {
    #           inherit name;
    #           value = { };
    #         }) apiKeys
    #       );
    #       templates."openclaw-env" = {
    #         content = lib.concatMapStrings (name: "${name}=${config.sops.placeholder.${name}}\n") apiKeys;
    #         owner = "openclaw";
    #       };
    #     };
    # })
  ];
}

{
  modulesPath,
  lineage,
  config,
  lib,
  ...
}:

let
  isDigitalOcean = lineage.has.form "Digital Ocean Droplet";
in
{
  # Imports cannot be within 'config' so we import them conditionally here.
  imports = lib.optional isDigitalOcean (modulesPath + "/virtualisation/digital-ocean-config.nix");

  config = lib.mkMerge [

    # Enable WSL support for WSL platforms.
    (lib.mkIf (lineage.has.form "WSL") {
      wsl = {
        enable = true;
        startMenuLaunchers = true;
        useWindowsDriver = false;
        defaultUser = config.internal.primaryUser;
        wslConf.user.default = config.wsl.defaultUser;
        interop = {
          includePath = true;
          register = true;
        };
      };
    })

    # Enable Digital Ocean specific configuration.
    (lib.mkIf isDigitalOcean {

      # Migrate SSH keys from 'root' to 'nixos' user (disables Root login).
      systemd.services.digitalocean-ssh-keys = {
        description = lib.mkForce "Set ssh keys provided by Digital Ocean";
        script = lib.mkForce ''
          set -e
          mkdir -m 0700 -p /home/nixos/.ssh
          jq -er '.public_keys[]' /run/do-metadata/v1.json > /home/nixos/.ssh/authorized_keys
          chmod 600 /home/nixos/.ssh/authorized_keys
        '';
        unitConfig.ConditionPathExists = lib.mkForce "!/home/nixos/.ssh/authorized_keys";
      };

      services.do-agent.enable = true;

      networking = {
        dhcpcd.enable = true;

        # By setting it to an empty string the digital ocean service can get it from metadata
        hostName = "";
      };
    })

    # Enables the Azure Linux Agent for Azure VMs, which provides features like provisioning, monitoring, and management.
    (lib.mkIf (lineage.has.form "Microsoft Azure") {
      services = {
        waagent.enable = true;
        logrotate.enable = lib.mkForce true;
      };
    })

    # Enables Google OS Login for GCE instances, which allows you to manage SSH access via IAM.
    (lib.mkIf (lineage.has.form "Google Compute Engine") {
      security.googleOsLogin.enable = true;
    })

    # Creates more predictable interface names
    # Documentation Reference: https://wiki.nixos.org/wiki/Install_NixOS_on_Oracle_Cloud
    (lib.mkIf (lineage.has.form "Oracle Cloud Infrastructure") {
      boot.kernelParams = [ "net.ifnames=0" ];
    })
  ];
}

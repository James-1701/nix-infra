# Not very clean and doesnt follow great design scoping, but gets the job done for now

{
  config,
  pkgs,
  lib,
  ...
}:
let
  mcxboxbroadcast = pkgs.callPackage ../pkgs/mcxboxbroadcast.nix { };
  cfg = config.services.mcxboxbroadcast;
in
{
  options.services.mcxboxbroadcast.enable = lib.mkEnableOption "MCXboxBroadcast Xbox Live server broadcaster";

  config = lib.mkIf cfg.enable {
    systemd.services.mcxboxbroadcast = {
      description = "MCXboxBroadcast Xbox Live server broadcaster";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${mcxboxbroadcast}/bin/mcxboxbroadcast";
        WorkingDirectory = "/var/lib/mcxboxbroadcast";
        StateDirectory = "mcxboxbroadcast";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "mcxboxbroadcast";
        Group = "mcxboxbroadcast";
      };
    };

    users.users.mcxboxbroadcast = {
      isSystemUser = true;
      group = "mcxboxbroadcast";
      home = "/var/lib/mcxboxbroadcast";
    };
    users.groups.mcxboxbroadcast = { };

    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/mcxboxbroadcast";
        user = "mcxboxbroadcast";
        group = "mcxboxbroadcast";
        mode = "0750";
      }
    ];
  };
}

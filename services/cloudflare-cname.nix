# FIXME: RUNS AS ROOT FIX LATER

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cloudflare-cname;
in
{
  options.services.cloudflare-cname = {
    enable = lib.mkEnableOption "Cloudflare CNAME DNS management";

    zone = lib.mkOption {
      type = lib.types.str;
      example = "jameshollister.org";
      description = "The Cloudflare zone (domain) to manage records in.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/cloudflare-token";
      description = "Path to a file containing the Cloudflare API token.";
    };

    records = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "git" = "my-host.seagull-court.ts.net";
        "nextcloud" = "my-host.seagull-court.ts.net";
      };
      description = ''
        Attribute set of CNAME records to manage. Keys are subdomains,
        values are the CNAME targets. Records are upserted: if a record
        with the same name already exists it will be replaced.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cloudflare-cname = {
      description = "Cloudflare CNAME DNS management";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = cfg.tokenFile;
      };

      script =
        let
          curl = "${pkgs.curl}/bin/curl";
          jq = "${pkgs.jq}/bin/jq";

          # Generate a script fragment for each record
          recordScripts = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: target: ''
              echo "Processing CNAME: ${name}.${cfg.zone} -> ${target}"

              # Get the zone ID
              ZONE_ID=$(${curl} -sf -X GET \
                "https://api.cloudflare.com/client/v4/zones?name=${cfg.zone}" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                | ${jq} -r '.result[0].id')

              if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
                echo "ERROR: Could not find zone ID for ${cfg.zone}"
                exit 1
              fi

              # Check if a record with this name already exists
              EXISTING_ID=$(${curl} -sf -X GET \
                "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=${name}.${cfg.zone}" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                | ${jq} -r '.result[0].id')

              if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ]; then
                echo "Deleting existing record: $EXISTING_ID"
                ${curl} -sf -X DELETE \
                  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING_ID" \
                  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                  -H "Content-Type: application/json"
              fi

              # Create the new CNAME record
              ${curl} -sf -X POST \
                "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data '{
                  "type": "CNAME",
                  "name": "${name}",
                  "content": "${target}",
                  "ttl": 1,
                  "proxied": false
                }'

              echo "Done: ${name}.${cfg.zone} -> ${target}"
            '') cfg.records
          );
        in
        ''
          set -euo pipefail
          CLOUDFLARE_API_TOKEN=$(cat ${cfg.tokenFile})
          ${recordScripts}
        '';
    };
  };
}

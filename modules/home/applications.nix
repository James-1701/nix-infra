# modules/home/firefox.nix
{
  lineage,
  pkgs,
  ...
}:

{
  # Installs Firefox and configures it with some nix search engines. Only applies if the "Desktop" usage is enabled.
  # Later I will make the configuration far more declarative
  programs.firefox = {
    enable = lineage.has.usage "Desktop";
    package = pkgs.firefox-devedition;
    profiles = {
      dev-edition-default = {
        isDefault = true;
        id = 0;
        search = {
          default = "bing";
          force = true;
          engines = {
            "Nix Packages" = {
              urls = [ { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; } ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "Nix Options" = {
              urls = [ { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}"; } ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@no" ];
            };
            "NixOS Wiki" = {
              urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
              icon = "https://wiki.nixos.org/favicon.ico";
              definedAliases = [ "@nw" ];
            };
          };
        };
      };
    };
  };
}

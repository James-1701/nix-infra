{
  lib,
  lineage,
  ...
}:

{
  # Setup connectivity protocols like bluetooth and thunderbolt
  config = lib.mkMerge [
    { services.hardware.bolt.enable = lineage.has.form "Laptop"; }

    (lib.mkIf (lineage.has.usage "Desktop") {
      hardware.bluetooth.enable = true;
      environment.persistence."/nix/persist".directories = [ "/var/lib/bluetooth" ];
    })
  ];
}

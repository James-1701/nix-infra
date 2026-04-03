{
  lineage,
  lib,
  ...
}:

{
  # Configures virt-manager settings for users with libvirt usage
  dconf.settings = lib.mkIf (lineage.has.usage "libvirt") {

    # Required or extremely helpful to use virt-manager at all
    "org/virt-manager/virt-manager".xmleditor-enabled = true;
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    # Optional but nice to have
    "org/virt-manager/virt-manager/confirm" = {
      delete-storage = false;
      forcepoweroff = false;
      removedev = false;
      unapplied-dev = false;
    };
    "org/virt-manager/virt-manager/stats" = {
      enable-disk-poll = true;
      enable-memory-poll = true;
      enable-net-poll = true;
    };
    "org/virt-manager/virt-manager/vmlist-fields" = {
      disk-usage = true;
      host-cpu-usage = true;
      memory-usage = true;
      network-traffic = true;
    };
  };
}

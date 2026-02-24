{
  lineage,
  lib,
  ...
}:

let
  isHardened = lineage.has.usage "hardened";
in
{
  config = lib.mkMerge [
    {
      services.journald.audit = isHardened;

      security = {
        auditd.enable = isHardened;
        unprivilegedUsernsClone = true; # Needed for many programs to work
        sudo = {
          enable = true;
          execWheelOnly = true;
          wheelNeedsPassword = true;
          extraConfig = "Defaults lecture = always";
        };
      };
    }

    # Enables fingerprint reader and saves the stored fingerprints
    (lib.mkIf (lineage.has.usage "fprint") {
      services.fprintd.enable = true;
      environment.persistence."/nix/persist".directories = [ "/var/lib/fprint" ];
    })

    # Enables Secure Boot + TPM support
    (lib.mkIf (lineage.has.boot "Secure Boot") {
      systemd.tpm2.enable = true;
      security.tpm2 = {
        enable = true;
        pkcs11.enable = true;
      };

      # Lanzaboote is the project to boot nixos on Secure Boot systems
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };

      environment.persistence."/nix/persist".directories = [ "/var/lib/sbctl" ];
    })
  ];
}

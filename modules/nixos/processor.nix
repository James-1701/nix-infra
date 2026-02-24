{
  lib,
  lineage,
  ...
}:

{
  hardware.cpu = {
    x86.msr.enable = lineage.has.cpu "x86_64"; # Needed for some software and features
    intel.updateMicrocode = lineage.has.cpu "Intel";
    amd.updateMicrocode = lineage.has.cpu "AMD";
  };

  # Settings for running virtual machines (Currently Intel only)
  boot = {

    # Enables IOMMU for device passthrough on Intel CPUs
    kernelParams = lib.optionals (lineage.has.cpu "Intel") [
      "intel_iommu=on"
    ];

    # Enables nested virtualization on Intel CPUs
    extraModprobeConfig = lib.mkIf (lineage.has.cpu "Intel") ''
      options kvm_intel nested=1
    '';
  };
}

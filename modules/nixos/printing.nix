{
  pkgs,
  lineage,
  ...
}:

{
  # Enables printing with proper drivers and a simple configuration
  services.printing = {
    enable = lineage.has.usage "Printing";
    startWhenNeeded = true;
    drivers = with pkgs; [
      brgenml1cupswrapper
      brgenml1lpr
      brlaser
      carps-cups
      cups-filters
      gutenprint
      gutenprintBin
      hplip
      hplipWithPlugin
      postscript-lexmark
      samsung-unified-linux-driver
      splix
    ];
    browsing = true;
    browsedConf = ''
      BrowseDNSSDSubTypes _cups,_print
      BrowseLocalProtocols all
      BrowseRemoteProtocols all
      CreateIPPPrinterQueues All
      BrowseProtocols all
    '';
  };
}

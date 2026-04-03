_: {

  # Enables the home-manager command for management
  programs.home-manager.enable = true;

  # Auto updates and removes old generations of home-manager profiles
  services.home-manager = {
    autoUpgrade = {
      enable = true;
      frequency = "weekly";
    };
    autoExpire = {
      enable = true;
      frequency = "weekly";
      store.cleanup = true;
    };
  };
}

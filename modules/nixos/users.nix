{
  config,
  lib,
  lineage,
  ...
}:

let
  # Gets the defined users for the system
  targetPrimary = lineage.traits.users.primary or "nixos";
  primaryEnabled = targetPrimary != null;
  definedUsers = lineage.traits.users.info or { };
  users =
    if primaryEnabled && !(builtins.hasAttr targetPrimary definedUsers) then
      definedUsers // { ${targetPrimary} = { }; }
    else
      definedUsers;

  # For systems where SOPS cannot be easily immediately deployed, this is a fallback password hash for the primary user to ssh into
  # This is only intended for short-term use during initial setup and should be CHANGED IMMEDIATELY AFTER DEPLOYMENT.
  insecureSetupHash = "$y$jFT$XY7yZ.ocRfJuCaqz99Lgu0$D31WwLebnOgtEN6oE2eJPI/GpwMOj4AS2gkOlDrbxB2";

  # Capitalize the first letter of a string and lowercase the rest for user descriptions.
  capitalize =
    string:
    lib.toUpper (builtins.substring 0 1 string) + lib.toLower (builtins.substring 1 (-1) string);
in
{
  # Exposes the Primary user, superusers, and the rest of the users for use in other modules.
  options.internal = {
    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = targetPrimary;
      description = "The username of the primary system user.";
    };
    superusers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Automatically generated list of usernames with superuser privileges.";
      default = lib.unique (
        (lib.optional primaryEnabled targetPrimary)
        ++ (lib.attrNames (lib.filterAttrs (_: user: user.superuser or false) users))
      );
      readOnly = true;
    };
    users = lib.mkOption {
      description = "Internal representation of user definitions.";
      default = users;
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = lib.types.attrs;

          options.persistence = lib.mkOption {
            type = lib.types.enum [
              "none"
              "default"
              "full"
            ];
            default = if lineage.has.usage "Desktop" then "default" else "none";
            description = "Persistence level: 'none' (ephemeral), 'default' (standard), or 'full'.";
          };
        }
      );
    };
  };

  # General user settings
  config = {
    users = {
      mutableUsers = false; # Prevents users from being modified after creation, enhancing reproducibility and security.
      enforceIdUniqueness = true;
      allowNoPasswordLogin = true;

      # Locks the root user account
      users = {
        root.hashedPassword = lib.mkForce "!";
      }

      # Setups up the defined users with their respective configurations
      // (lib.mapAttrs (
        name: data:
        let

          # Gets the `primary-user-password` SOPS secret file for the primary user if it exists, as a fallback password setup for initial deployment
          passwordFile =
            data.passwd
              or (if name == targetPrimary then "/run/secrets-for-users/primary-user-password" else null);

          # Sets the password to the insecure hashed password if chosen
          # Otherwise uses the SOPS password file if it exists
          # If neither are set it leaves the password empty (which allows for passwordless login)
          passwordSetup =
            if (lineage.has.usage "Insecure Setup Password") then
              {
                hashedPassword = insecureSetupHash;
              }
            else if passwordFile != null then
              {
                hashedPasswordFile = passwordFile;
              }
            else
              {
                password = "";
              };
        in
        {
          # Creates the user with the specified name, configurations and sane defaults
          isNormalUser = true;
          uid = data.uid or null;
          description = data.description or (capitalize name);
          home = "/home/${name}";
          homeMode = "700";
          useDefaultShell = data.shell or true;
          extraGroups = lib.optionals (lib.elem name config.internal.superusers) [ "wheel" ];
        }
        // passwordSetup # Applies the password setup from above
      ) users);
    };

    # Sets up desktop auto-login for the primary user
    services.displayManager.autoLogin = lib.mkIf (primaryEnabled && (lineage.has.usage "Desktop")) {
      enable = true;
      user = targetPrimary;
    };

    # If the user has `full` persistence, this persists their entire home directory.
    environment.persistence."/nix/persist".directories = lib.mapAttrsToList (name: _: "/home/${name}") (
      lib.filterAttrs (_: user: user.persistence == "full") config.internal.users
    );
  };
}

# This is my flake for my NixOS fleet configuration
# Flakes are self-contained, reproducible collection of Nix code with pinned inputs and well-defined outputs

{
  description = "My Nixos Fleet Flake";

  # Flake inputs are essentially the dependencies for a flake in this case a flake that builds a NixOS system
  inputs = {
    nixpkgs.url = "github:Nixos/nixpkgs/e45659e608efeb9f3921b0e41d0b619cdd6ffd92";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    lineage.url = "github:James-1701/nix-lineage";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

      # Using `inputs.<name>.follows` allows flake inputs to use the same instance of youan input as your flake uses
      # This can prevent re-downloading many versions of the same thing, ex: having nixpkgs unstable, 25.11 & 25.5.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  # Flake outputs are just what the flake build
  outputs =

    # The `{ ... }:` function signature destructures the input attribute set, requiring `self` and `nixpkgs`.
    {
      self,
      nixpkgs,
      ...

      # `@inputs` binds the full `inputs` set for later use (The `...` allows additional inputs not explicitly named, ex: `inputs.lineage`).
    }@inputs:
    let

      # Adds `lib` from `nixpkgs` to the current scope
      inherit (nixpkgs) lib;

      # Gets the current version of my lineage library
      lineageLib = inputs.lineage.lib;

      # Sets the lienage database to the one for my system
      # Note: any time you see just a path in nix it uses the file `default.nix` therefore `./lineage` is the same as `./lineage/default`
      lineageDB = lineageLib.buildDB ./lineage;

      # This grabs all my hosts from my hosts directory that end with ".nix" and dont start with "_"
      hosts = builtins.attrNames (
        lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n && !lib.hasPrefix "_" n) (
          builtins.readDir ./hosts
        )
      );

      # Gets a list of all the system architectures supported by flakes
      # Also creates a helper function that iterates over the above architectures
      systems = import (nixpkgs + "/lib/systems/flake-systems.nix") { };
      forEachSystem = lib.genAttrs systems;

      # Builds the treefmt formatter to use later
      # This uses `forEachSystem` to generate this helper for each system in the `systems` list.
      treefmtEval = forEachSystem (
        system:

        # Builds the treefmt formatter for the current system
        # Note `legacyPackages` is used because `treefmt-nix.lib.evalModule` expects a full nixpkgs `pkgs` attribute set, which legacyPackages provides.
        inputs.treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs = {

            # Formatters for all the code found in this repo
            nixfmt.enable = true;
            shfmt.enable = true;
            taplo.enable = true;
            yamlfmt = {
              enable = true;
              settings.formatter.retain_line_breaks_single = true;
            };
            mdformat = {
              enable = true;
              settings.wrap = 80;
              plugins = plugin: [ plugin.mdformat-gfm ];
            };
          };
        }
      );

      # Sets the formatter to the nixfmt we built above
      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

      # This helper mostly exists to wrap both outputs that require `pkgs` together
      flakeOutputs = forEachSystem (
        system:
        let

          # Exposes `pkgs` in the same way they are to the modules system
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Along with evaluating the flake, this adds the pre-commit hooks to `nix flake check`
          checks = {

            # This adds all the precommit hooks to the system, IMHO everyone should use precommit, using them in nix is extremely simple and flexible
            pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {

                # I run treefmt in precommit to ensure my code doesn't get committed without formatting
                treefmt = {
                  enable = true;
                  package = treefmtEval.${system}.config.build.wrapper;
                };

                # This repo is my most vulnerable to secret exposure, which is why I use gitleaks instead of ripsecrets, like I do in my other repos.
                # While I make sure to encrypt everything via SOPS, it is still best practice to run secrets detection to prevent secret leaks,
                # This alone is not enough and secrets should always be handled carefully including common patterns to your gitignore,
                # using precommit & CI and most of all paying attention to what you are doing anytime you touch them
                pre-commit-hook-ensure-sops.enable = true;
                gitleaks = {
                  enable = true;
                  pass_filenames = false;
                  entry = "${pkgs.gitleaks}/bin/gitleaks git --pre-commit --redact --staged --verbose";
                };

                # Ensures all the system flakes evaluate
                # flake-checker.enable = true;

                # Various linters for code quality
                shellcheck.enable = true;
                deadnix.enable = true;
                statix.enable = true;
                markdownlint = {
                  enable = true;
                  settings.configuration = {
                    MD013 = {
                      code_blocks = false;
                      tables = false;
                      urls = false;
                    };
                    MD060.style = "any";
                    MD041 = false;
                  };
                };

                # Ensures scripts are all executable and nothing else
                check-shebang-scripts-are-executable.enable = true;
                check-executables-have-shebangs.enable = true;

                # Ensures im not committing symlinks or huge files
                check-symlinks.enable = true;
                check-added-large-files.enable = true;

                # Makes sure I don't have any blatant typos
                typos = {
                  enable = true;
                  settings.config.default.extend-words =
                    let
                      keys = [
                        "UE"
                        "ND"
                        "hda"
                        "Iy"
                        "dne"
                        "Cll"
                      ];
                    in
                    builtins.listToAttrs (
                      map (key: {
                        name = key;
                        value = key;
                      }) keys
                    );
                };

                # Some file consistency checks
                editorconfig-checker.enable = true;
                end-of-file-fixer.enable = true;
                trim-trailing-whitespace.enable = true;

                # Ensures there wont be a merge conflict
                check-merge-conflicts.enable = true;
              };
            };
          };

          # Creates a developer shell used by direnv (recommended) or `nix develop` to install all my developer tools
          devShells = {
            default = pkgs.mkShell {

              # Makes sure the precommit shell hook is run
              inherit (self.checks.${system}.pre-commit-check) shellHook;
              packages =
                with pkgs;
                [
                  # Adds the treefmt we built earlier
                  treefmtEval.${system}.config.build.wrapper

                  # Various CLI tools for working with this repo
                  nixos-anywhere
                  sops
                  age
                  ssh-to-age
                  yq-go
                  neovim
                  fzf
                  ripgrep
                  git
                  jq
                  nh

                  # Nix LSP for editors
                  nixd
                ]

                # Also adds all the packages from pre-commit git hooks
                ++ self.checks.${system}.pre-commit-check.enabledPackages;
            };
          };
        }
      );

      # Gets the `checks` and `devshells` from above
      checks = forEachSystem (system: flakeOutputs.${system}.checks);
      devShells = forEachSystem (system: flakeOutputs.${system}.devShells);

      # This block builds each of the NixOS system from the host file we read from before, removing the ".nix" suffix
      nixosConfigurations = lib.genAttrs (map (lib.removeSuffix ".nix") hosts) (
        name:
        let

          # Builds lineage object with the given host
          builtLineage = lineageLib.buildHost lineageDB ./hosts/${name}.nix;

          # Compute host system once
          hostSystem = builtins.head (
            builtins.filter (
              sys:
              (builtins.elem (builtins.head (lib.splitString "-" sys)) builtLineage.lineage.traits.cpu)
              && (lib.hasSuffix "linux" sys)
            ) lib.systems.flakeExposed
          );

          # Makes `pkgs-stable`, `inputs` and `lineage` directly available for modules
          specialArgs = {
            pkgs-stable = inputs.nixpkgs-stable.legacyPackages.${hostSystem};
            inherit (builtLineage) lineage;
            inherit inputs;
          };
        in

        # Builds the NixOS system
        lib.nixosSystem {
          inherit specialArgs;

          # Defines the modules to be used for the NixOS system
          modules = [
            {
              # Sets the hostname and architecture from within the flake
              networking.hostName = lib.mkDefault name;
              nixpkgs.hostPlatform = hostSystem;
            }

            # Imports the NixOS modules defined by lineage into the system
            specialArgs.lineage.hostModule

            # Imports the rest of my configuration
            ./modules
          ];
        }
      );
    in
    {
      # Exposing every output in one inherit block feels cleaner and more understandable to me which is why I do it
      inherit
        nixosConfigurations
        formatter
        checks
        devShells
        ;
    };
}

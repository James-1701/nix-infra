{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Sets the shell to ZSH
  users.defaultUserShell = pkgs.zsh;

  # While useful enabling this can prevent system from booting so I force it off
  services.envfs.enable = lib.mkForce false;

  environment = {
    systemPackages = with pkgs; [
      zellij # A terminal workspace and multiplexer, mostly for ssh session persistence and management
      eza # A modern replacement for ls with more features and better performance
    ];
    shellAliases = {
      ls = "${pkgs.eza}/bin/eza --classify --icons=auto";
    };

    # Setup environment variables
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      HISTCONTROL = "ignoredups";
      HISTSIZE = 1000;
    };

    persistence."/nix/persist".users = lib.mapAttrs (_: _: {

      # Persist needed ZSH history and setup
      files = [
        ".p10k.zsh"
        ".zsh_history"
      ];

      # Persists the nix-index cache for use with comma
      directories = [
        ".cache/nix-index"
      ];
    }) (lib.filterAttrs (_: user: user.persistence == "default") config.internal.users);
  };

  programs = {

    # Sets up Neovim as the CLI text editor
    nano.enable = false;
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;
      configure = {
        customRC = ''
          set number
          set list
        '';
      };
    };

    # Allows adding a comma before commands to run them if they are not in the PATH
    # Ex: `, htop`
    nix-index-database.comma.enable = true;

    # Drop in `cd` replacement with support for remembering directories commonly entered
    zoxide = {
      enable = true;
      flags = [ "--cmd cd" ];
    };

    # CLI fuzzy search tool
    fzf = {
      fuzzyCompletion = true;
      keybindings = true;
    };

    zsh = {

      # Enables ZSH with useful features and settings
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableLsColors = true;
      vteIntegration = true;
      histSize = 1000000;
      syntaxHighlighting.enable = false; # I use zsh-fast-syntax-highlighting instead

      # Disable Zsh's first-run configuration prompt because its managed declaratively
      shellInit = "zsh-newuser-install() { :; }";

      # Sets up interactive shells with the following features:
      # - bash like keybind support
      # - advanced history features
      # - fzf powered completion menus
      # - abbreviations (like aliases, but expand to the original command)
      # - syntax highlighting (using a faster, more capable plugin)
      # - Powerlevel10k ZSH theme setup
      # - Deferred loading via zsh-defer to speed up shell startup
      interactiveShellInit = ''
        source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh

        load_plugins() {

          autoload -U select-word-style
          select-word-style bash # Makes Ctrl+Arrow stop at spaces (like Bash)

          bind_keys() {
            bindkey "^[[1;5C" forward-word
            bindkey "^[[5C"   forward-word
            bindkey "\e[1;5C" forward-word
            bindkey "^[[1;6C" forward-word  # Sometimes Ctrl+Shift+Right

            bindkey "^[[1;5D" backward-word
            bindkey "^[[5D"   backward-word
            bindkey "\e[1;5D" backward-word
            bindkey "^[[1;6D" backward-word # Sometimes Ctrl+Shift+Left

            bindkey "^[[A" history-search-backward
            bindkey "^[[B" history-search-forward

            bindkey "^[[3;5~" kill-word          # Ctrl + Delete
            bindkey '^H'      backward-kill-word # Ctrl + Backspace
          }

          bind_keys

          autoload -U add-zsh-hook
          add-zsh-hook precmd bind_keys

          setopt HIST_IGNORE_ALL_DUPS      # Clean history (delete duplicates)
          setopt SHARE_HISTORY             # Share history between terminals
          setopt HIST_FCNTL_LOCK           # Better file locking
          setopt EXTENDED_HISTORY          # Save timestamps in history
          setopt RM_STAR_WAIT              # Wait 10s when running 'rm *'

          source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
          source ${pkgs.zsh-abbr}/share/zsh/zsh-abbr/zsh-abbr.zsh

          {
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: value: "abbr --session ${lib.escapeShellArg "${name}=${value}"}") {
                c = "clear";
                h = "history";
                svi = "sudoedit";

                l = "ls -alh";
                ll = "ls -l";
                la = "ls -a";
                lla = "ls -la";
                tree = "${pkgs.eza}/bin/eza --tree --icons=auto";

                g = "git";
                gs = "git status";
                ga = "git add";
                gaa = "git add --all";
                gc = "git commit -m";
                gca = "git commit --amend";
                gcl = "git clone";

                gb = "git branch";
                gba = "git branch -a";
                gco = "git checkout";
                gsw = "git switch";
                gcb = "git checkout -b";
                gp = "git push";
                gpl = "git pull";
                gup = "git pull --rebase";
                gf = "git fetch --all";
                gd = "git diff";
                gds = "git diff --staged";
                gl = "git log --oneline --graph --decorate --all";
                gsta = "git stash";
                gstp = "git stash pop";
              }
            )}
          }

          source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
        }

        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

        zsh-defer load_plugins
      '';

      # Sets up ZSH autosuggestions
      autosuggestions = {
        enable = true;
        async = true;
        highlightStyle = "fg=cyan";
        strategy = [
          "history"
          "completion"
        ];
        extraConfig = {
          "ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" = "20";
        };
      };
    };
  };
}

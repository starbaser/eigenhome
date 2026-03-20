# Shell option stubs — accepts writes from HM program modules.
# HM modules write to programs.zsh.initContent, programs.bash.initExtra, etc.
# These options collect the content; shell-bridge.nix routes it to rum or files.
#
# Freeform submodules: typed options for what shell-bridge.nix reads, plus
# freeform fallback for arbitrary writes from imported HM program modules
# (e.g., git.nix writes programs.nushell.environmentVariables).
{lib, ...}: let
  inherit (lib) mkOption types;

  linesOpt = description:
    mkOption {
      type = types.lines;
      default = "";
      inherit description;
    };

  aliasesOpt = mkOption {
    type = types.attrsOf types.str;
    default = {};
    description = "Shell aliases.";
  };

  sessionVarsOpt = mkOption {
    type = types.attrsOf (types.oneOf [
      types.str
      types.path
      types.int
    ]);
    default = {};
    description = "Per-shell session variables.";
  };

  # Freeform shell program submodule: typed options + catch-all for HM compat.
  mkShellProg = opts:
    mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
        options = opts;
      };
      default = {};
    };
in {
  options.programs = {
    bash = mkShellProg {
      enable = lib.mkEnableOption "bash configuration";
      initExtra = linesOpt "Extra commands for .bashrc.";
      bashrcExtra = linesOpt "Extra .bashrc content (appended after initExtra).";
      profileExtra = linesOpt "Extra commands for .bash_profile.";
      shellAliases = aliasesOpt;
      sessionVariables = sessionVarsOpt;
    };

    zsh = mkShellProg {
      enable = lib.mkEnableOption "zsh configuration";
      initContent = linesOpt "Content for .zshrc (main init).";
      initExtra = linesOpt "Extra commands appended to .zshrc.";
      envExtra = linesOpt "Extra commands for .zshenv.";
      loginExtra = linesOpt "Extra commands for .zlogin.";
      logoutExtra = linesOpt "Extra commands for .zlogout.";
      shellAliases = aliasesOpt;
      sessionVariables = sessionVarsOpt;
    };

    fish = mkShellProg {
      enable = lib.mkEnableOption "fish configuration";
      shellInit = linesOpt "Commands run on every fish instance.";
      interactiveShellInit = linesOpt "Commands run on interactive fish instances.";
      shellInitLast = linesOpt "Commands run last on every fish instance.";
      loginShellInit = linesOpt "Commands run on login fish instances.";
      shellAliases = aliasesOpt;
      shellAbbrs = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Fish abbreviations.";
      };
      functions = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        description = "Fish functions, keyed by function name (body only).";
      };
    };

    ion = mkShellProg {
      enable = lib.mkEnableOption "ion configuration";
      initExtra = linesOpt "Extra commands for ion init.";
    };

    nushell = mkShellProg {
      enable = lib.mkEnableOption "nushell configuration";
      extraConfig = linesOpt "Extra config.nu content.";
      extraEnv = linesOpt "Extra env.nu content.";
    };
  };
}

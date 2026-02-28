# HM-compatible home.* option declarations.
# Uses hmExtLib (lib extended with lib.hm) for HM file-type.nix import.
{
  config,
  hmExtLib,
  hmSrc,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;

  # Import HM's file-type.nix with the extended lib that includes lib.hm.
  hmFileType = import "${hmSrc}/modules/lib/file-type.nix" {
    lib = hmExtLib;
    inherit pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in {
  options.home = {
    file = mkOption {
      type = hmFileType.fileType "home.file" "home directory" config.home.homeDirectory;
      default = {};
      description = "Attribute set of files to link into the user home directory.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Packages to install for this user.";
    };

    sessionVariables = mkOption {
      type = types.attrsOf (types.oneOf [
        types.str
        types.path
        types.int
      ]);
      default = {};
      description = "Environment variables to set on session start.";
    };

    sessionPath = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra directories to prepend to PATH.";
    };

    username = mkOption {
      type = types.str;
      readOnly = true;
      description = "The user's login name.";
    };

    homeDirectory = mkOption {
      type = types.path;
      readOnly = true;
      description = "The user's home directory path.";
    };

    profileDirectory = mkOption {
      type = types.str;
      readOnly = true;
      description = "Profile directory path.";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "24.11";
      description = "State version for HM module backwards-compatibility.";
    };

    # Activation scripts — topo-sorted and written to an executable script
    # by activation-runner.nix. Executed by the NixOS hjem-compat-activate@
    # service after file linking. HM built-in phases are filtered out.
    activation = mkOption {
      type = hmExtLib.hm.types.dagOf types.str;
      default = {};
      description = "DAG of activation scripts, executed after hjem links files.";
    };

    # Global shell integration toggles.
    shell = {
      enableBashIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Default value for per-program Bash integration options.";
      };
      enableFishIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Default value for per-program Fish integration options.";
      };
      enableIonIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Default value for per-program Ion integration options.";
      };
      enableNushellIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Default value for per-program Nushell integration options.";
      };
      enableZshIntegration = mkOption {
        type = types.bool;
        default = true;
        description = "Default value for per-program Zsh integration options.";
      };
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Shell aliases applied to all enabled shells.";
    };

    # PATH-like session variables (lists joined with colons).
    sessionSearchVariables = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      description = "PATH-like session variables (lists joined with colons).";
    };

    # Profile path alias for HM compat.
    path = mkOption {
      type = types.str;
      readOnly = true;
      description = "Profile path (aliases profileDirectory for HM compat).";
    };

    # Build/profile hooks — sinks (hjem doesn't build an HM-style profile).
    extraActivationPath = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Extra packages in activation PATH (accepted, not used by hjem).";
    };

    extraBuilderCommands = mkOption {
      type = types.lines;
      default = "";
      description = "Extra builder commands (accepted, not used by hjem).";
    };

    extraProfileCommands = mkOption {
      type = types.lines;
      default = "";
      description = "Extra profile build commands (accepted, not used by hjem).";
    };

    extraOutputsToInstall = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra outputs to install (accepted, forwarded to packages).";
    };

    extraDependencies = mkOption {
      type = types.listOf types.anything;
      default = [];
      description = "Extra closure dependencies (accepted, not used by hjem).";
    };

    checks = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Build-time checks (accepted, not used by hjem).";
    };

    # Locale settings — translated to session variables by translation.nix.
    language = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf (types.nullOr types.str);
      };
      default = {};
      description = "Locale language settings (translated to session variables).";
    };

    # X11 keyboard config — sink on Wayland.
    keyboard = mkOption {
      type = types.nullOr (types.submodule {
        freeformType = types.attrsOf types.anything;
      });
      default = null;
      description = "Keyboard layout config (accepted, not used on Wayland).";
    };

    preferXdgDirectories = lib.mkEnableOption "Prefer XDG directories for config placement";

    emptyActivationPath = mkOption {
      type = types.bool;
      default = true;
      description = "Clear PATH before activation (accepted, not used by hjem).";
    };

    enableNixpkgsReleaseCheck = mkOption {
      type = types.bool;
      default = true;
      description = "Nixpkgs release check (accepted, not used by hjem).";
    };
  };
}

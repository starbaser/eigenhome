# HM-compatible home.* option declarations.
# Provides the option surface that HM program modules expect to read from and write to.
{
  config,
  hmSrc,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  # Import HM's file-type.nix to get the exact type definition HM modules expect.
  hmFileType = import "${hmSrc}/modules/lib/file-type.nix" {
    inherit lib pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in
{
  options.home = {
    file = mkOption {
      type = hmFileType.fileType "home.file" "home directory" config.home.homeDirectory;
      default = { };
      description = "Attribute set of files to link into the user home directory.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Packages to install for this user.";
    };

    sessionVariables = mkOption {
      type = types.attrsOf (types.oneOf [
        types.str
        types.path
        types.int
      ]);
      default = { };
      description = "Environment variables to set on session start.";
    };

    sessionPath = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra directories to prepend to PATH.";
    };

    # Read-only identity — derived from hjem config in translation.nix.
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

    # Activation scripts — collected but not executed by hjem.
    activation = mkOption {
      type = lib.hm.types.dagOf types.str;
      default = { };
      description = "DAG of activation scripts (collected, not executed).";
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
      default = { };
      description = "Shell aliases applied to all enabled shells.";
    };
  };
}

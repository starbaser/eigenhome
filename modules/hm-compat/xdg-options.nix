# HM-compatible xdg.* option declarations.
# Uses hmExtLib for HM file-type.nix import.
{
  config,
  hmExtLib,
  hmSrc,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;

  hmFileType = import "${hmSrc}/modules/lib/file-type.nix" {
    lib = hmExtLib;
    inherit pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in {
  options.xdg = {
    enable = lib.mkEnableOption "XDG base directory specification";

    mimeApps = {
      enable = lib.mkEnableOption "MIME type associations" // {default = true;};
      defaultApplications = mkOption {
        type = types.attrsOf (types.either types.str (types.listOf types.str));
        default = {};
        description = "Default application for each MIME type.";
      };
      addedAssociations = mkOption {
        type = types.attrsOf (types.either types.str (types.listOf types.str));
        default = {};
        description = "Added MIME type associations.";
      };
      removedAssociations = mkOption {
        type = types.attrsOf (types.either types.str (types.listOf types.str));
        default = {};
        description = "Removed MIME type associations.";
      };
    };

    systemDirs = mkOption {
      type = types.submodule {freeformType = types.attrsOf types.anything;};
      default = {};
      description = "XDG system dirs (accepted for compat).";
    };

    portal = mkOption {
      type = types.submodule {freeformType = types.attrsOf types.anything;};
      default = {};
      description = "XDG desktop portal config (accepted for compat).";
    };

    desktopEntries = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "XDG desktop entries (accepted for compat).";
    };

    configHome = mkOption {
      type = types.str;
      readOnly = true;
      description = "XDG config home directory path.";
    };

    dataHome = mkOption {
      type = types.str;
      readOnly = true;
      description = "XDG data home directory path.";
    };

    cacheHome = mkOption {
      type = types.str;
      readOnly = true;
      description = "XDG cache home directory path.";
    };

    stateHome = mkOption {
      type = types.str;
      readOnly = true;
      description = "XDG state home directory path.";
    };

    configFile = mkOption {
      type = hmFileType.fileType "xdg.configFile" "XDG config directory" config.xdg.configHome;
      default = {};
      description = "Files to link into the XDG config directory.";
    };

    dataFile = mkOption {
      type = hmFileType.fileType "xdg.dataFile" "XDG data directory" config.xdg.dataHome;
      default = {};
      description = "Files to link into the XDG data directory.";
    };

    cacheFile = mkOption {
      type = hmFileType.fileType "xdg.cacheFile" "XDG cache directory" config.xdg.cacheHome;
      default = {};
      description = "Files to link into the XDG cache directory.";
    };

    stateFile = mkOption {
      type = hmFileType.fileType "xdg.stateFile" "XDG state directory" config.xdg.stateHome;
      default = {};
      description = "Files to link into the XDG state directory.";
    };
  };
}

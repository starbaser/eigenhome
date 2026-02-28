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

    mimeApps = mkOption {
      type = types.submodule {freeformType = types.attrsOf types.anything;};
      default = {};
      description = "MIME type associations (accepted for compat).";
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

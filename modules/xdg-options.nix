# HM-compatible xdg.* option declarations.
# HM modules read xdg.configHome etc. and write to xdg.configFile etc.
# These are the HM-named options; translation.nix wires them to hjem equivalents.
{
  config,
  hmSrc,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkOption types;

  hmFileType = import "${hmSrc}/modules/lib/file-type.nix" {
    inherit lib pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in
{
  options.xdg = {
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
      default = { };
      description = "Files to link into the XDG config directory.";
    };

    dataFile = mkOption {
      type = hmFileType.fileType "xdg.dataFile" "XDG data directory" config.xdg.dataHome;
      default = { };
      description = "Files to link into the XDG data directory.";
    };

    cacheFile = mkOption {
      type = hmFileType.fileType "xdg.cacheFile" "XDG cache directory" config.xdg.cacheHome;
      default = { };
      description = "Files to link into the XDG cache directory.";
    };

    stateFile = mkOption {
      type = hmFileType.fileType "xdg.stateFile" "XDG state directory" config.xdg.stateHome;
      default = { };
      description = "Files to link into the XDG state directory.";
    };
  };
}

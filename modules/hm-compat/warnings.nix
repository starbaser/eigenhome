# Warnings for unsupported HM features and dual-program conflicts.
{
  config,
  lib,
  options,
  osConfig ? null,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    filter
    filterAttrs
    isBool
    optional
    ;

  allFileSets = {
    "home.file" = config.home.file;
    "xdg.configFile" = config.xdg.configFile;
    "xdg.dataFile" = config.xdg.dataFile;
    "xdg.cacheFile" = config.xdg.cacheFile;
    "xdg.stateFile" = config.xdg.stateFile;
  };

  hasActivation = config.home.activation != {};
  hasNixosModule = osConfig != null;

  startServicesChanged = let
    v = config.systemd.user.startServices;
  in
    if isBool v
    then !v
    else v == "suggest" || v == "sd-switch";

  systemdSessionVars = config.systemd.user.sessionVariables;
  homeSessionVars = config.home.sessionVariables;
  # Only flag overlapping keys where the values differ — same-value duplicates
  # are an intentional HM pattern (e.g. qt.nix sets identical values in both).
  overlappingVars = filter (
    name: homeSessionVars ? ${name} && homeSessionVars.${name} != systemdSessionVars.${name}
  ) (attrNames systemdSessionVars);

  dualPrograms = [
    "starship"
    "git"
    "direnv"
    "kitty"
    "foot"
    "alacritty"
    "helix"
    "yazi"
    "zoxide"
    "fzf"
    "broot"
    "bottom"
    "ghostty"
    "lsd"
    "fastfetch"
    "neovide"
    "tealdeer"
  ];

  rumProgramEnabled = name: lib.attrByPath ["rum" "programs" name "enable"] false config;
  hmProgramEnabled = name: lib.attrByPath ["programs" name "enable"] false config;

  conflicts = filter (name: rumProgramEnabled name && hmProgramEnabled name) dualPrograms;
in {
  config.warnings =
    (optional (hasActivation && !hasNixosModule) ''
      eigenhome: home.activation scripts are defined but the NixOS activation module
      is not imported. Add eigenhome's nixosModules.default to your NixOS configuration
      to enable activation script execution after file linking.
      Entries: ${lib.concatStringsSep ", " (attrNames config.home.activation)}
    '')
    ++ (optional startServicesChanged ''
      eigenhome: systemd.user.startServices is set but service switching is handled
      by the NixOS eigenhome-activate@ service (daemon-reload only).
      Live service restart/stop is not supported.
    '')
    ++ (optional (overlappingVars != []) ''
      eigenhome: systemd.user.sessionVariables and home.sessionVariables define
      overlapping keys: ${lib.concatStringsSep ", " overlappingVars}.
      Both will be applied; home.sessionVariables takes precedence at shell level.
    '')
    ++ (optional (config.xdg.desktopEntries != {})
      "eigenhome: xdg.desktopEntries is not supported and will be ignored.")
    ++ (optional (config.xdg.portal != {})
      "eigenhome: xdg.portal is not supported (configure via NixOS options instead).")
    ++ (optional (config.systemd.user.tmpfiles.rules != [])
      "eigenhome: systemd.user.tmpfiles.rules is not supported and will be ignored.")
    ++ (map (name: ''
        eigenhome: Both rum.programs.${name} and programs.${name} (HM) are enabled.
        This may cause duplicate config files. Consider disabling one.
      '')
      conflicts);
}

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

  recursiveFiles = concatMap (
    setName: let
      fileSet = allFileSets.${setName};
    in
      map (name: "${setName}.\"${name}\".recursive") (
        attrNames (filterAttrs (_: f: f.recursive or false) fileSet)
      )
  ) (attrNames allFileSets);

  onChangeFiles = concatMap (
    setName: let
      fileSet = allFileSets.${setName};
    in
      map (name: "${setName}.\"${name}\".onChange") (
        attrNames (filterAttrs (_: f: (f.onChange or "") != "") fileSet)
      )
  ) (attrNames allFileSets);

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
  overlappingVars = filter (
    name: homeSessionVars ? ${name}
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
    (optional (recursiveFiles != []) ''
      eigenhome: The following files use 'recursive = true', which is not supported by hjem.
      Directories will be symlinked as a whole instead of per-leaf.
      Affected: ${lib.concatStringsSep ", " recursiveFiles}
    '')
    ++ (optional (onChangeFiles != []) ''
      eigenhome: The following files use 'onChange', which is not supported by hjem.
      Post-change hooks will not be executed.
      Affected: ${lib.concatStringsSep ", " onChangeFiles}
    '')
    ++ (optional (hasActivation && !hasNixosModule) ''
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
    ++ (map (name: ''
        eigenhome: Both rum.programs.${name} and programs.${name} (HM) are enabled.
        This may cause duplicate config files. Consider disabling one.
      '')
      conflicts);
}

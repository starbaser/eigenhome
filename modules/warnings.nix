# Warnings for unsupported HM features and dual-program conflicts.
{
  config,
  lib,
  options,
  ...
}:
let
  inherit (lib)
    attrNames
    concatMap
    filter
    filterAttrs
    optional
    ;

  # HM file sets that might use unsupported features.
  allFileSets = {
    "home.file" = config.home.file;
    "xdg.configFile" = config.xdg.configFile;
    "xdg.dataFile" = config.xdg.dataFile;
    "xdg.cacheFile" = config.xdg.cacheFile;
    "xdg.stateFile" = config.xdg.stateFile;
  };

  # Detect files using unsupported HM features.
  recursiveFiles = concatMap (
    setName:
    let
      fileSet = allFileSets.${setName};
    in
    map (name: "${setName}.\"${name}\".recursive") (
      attrNames (filterAttrs (_: f: f.recursive or false) fileSet)
    )
  ) (attrNames allFileSets);

  onChangeFiles = concatMap (
    setName:
    let
      fileSet = allFileSets.${setName};
    in
    map (name: "${setName}.\"${name}\".onChange") (
      attrNames (filterAttrs (_: f: (f.onChange or "") != "") fileSet)
    )
  ) (attrNames allFileSets);

  # Detect activation scripts.
  hasActivation = config.home.activation != { };

  # Detect dual rum + HM program conflicts.
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

  rumProgramEnabled = name: lib.attrByPath [ "rum" "programs" name "enable" ] false config;
  hmProgramEnabled = name: lib.attrByPath [ "programs" name "enable" ] false config;

  conflicts = filter (name: rumProgramEnabled name && hmProgramEnabled name) dualPrograms;
in
{
  config.warnings =
    (optional (recursiveFiles != [ ]) ''
      hjem-compat: The following files use 'recursive = true', which is not supported by hjem.
      Directories will be symlinked as a whole instead of per-leaf.
      Affected: ${lib.concatStringsSep ", " recursiveFiles}
    '')
    ++ (optional (onChangeFiles != [ ]) ''
      hjem-compat: The following files use 'onChange', which is not supported by hjem.
      Post-change hooks will not be executed.
      Affected: ${lib.concatStringsSep ", " onChangeFiles}
    '')
    ++ (optional hasActivation ''
      hjem-compat: home.activation scripts are set but cannot be executed by hjem's file linker.
      Activation entries: ${lib.concatStringsSep ", " (attrNames config.home.activation)}
    '')
    ++ (map (name: ''
      hjem-compat: Both rum.programs.${name} and programs.${name} (HM) are enabled.
      This may cause duplicate config files. Consider disabling one.
    '') conflicts);
}

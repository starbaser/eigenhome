# Translation layer: HM options → hjem primitives.
# Maps home.file → files, xdg.configFile → xdg.config.files, etc.
# Derives read-only HM values (home.username, xdg.configHome) from hjem config.
{
  config,
  hmExtLib,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    listToAttrs
    mapAttrsToList
    mkIf
    ;

  # Translate HM file entries to hjem file entries.
  # Uses the HM entry's resolved `target` as the hjem key, since HM modules
  # often use absolute paths as attrset keys (e.g., "${config.xdg.configHome}/starship.toml")
  # which HM's file-type.nix resolves to relative paths in `target`.
  translateFileEntry = _name: entry: {
    name = entry.target;
    value = {
      inherit (entry) enable;
      source = entry.source;
      executable = if entry.executable == true then true else false;
      clobber = entry.force;
    };
  };

  translateFileSet = fileSet:
    listToAttrs (
      mapAttrsToList translateFileEntry (filterAttrs (_: e: e.enable) fileSet)
    );

  hasFiles = set: (filterAttrs (_: e: e.enable) set) != { };
in
{
  config = {
    home = {
      username = config.user;
      homeDirectory = config.directory;
      profileDirectory = "/etc/profiles/per-user/${config.user}";
    };

    xdg = {
      configHome = config.xdg.config.directory;
      dataHome = config.xdg.data.directory;
      cacheHome = config.xdg.cache.directory;
      stateHome = config.xdg.state.directory;
    };

    # --- File translation ---
    files = mkIf (hasFiles config.home.file) (translateFileSet config.home.file);

    xdg.config.files =
      mkIf (hasFiles config.xdg.configFile) (translateFileSet config.xdg.configFile);

    xdg.data.files =
      mkIf (hasFiles config.xdg.dataFile) (translateFileSet config.xdg.dataFile);

    xdg.cache.files =
      mkIf (hasFiles config.xdg.cacheFile) (translateFileSet config.xdg.cacheFile);

    xdg.state.files =
      mkIf (hasFiles config.xdg.stateFile) (translateFileSet config.xdg.stateFile);

    # --- Package translation ---
    packages = config.home.packages;

    # --- Session variable translation ---
    environment.sessionVariables =
      let
        vars = config.home.sessionVariables;
        pathEntries = config.home.sessionPath;
      in
      mkIf (vars != { } || pathEntries != [ ]) (
        vars
        // (mkIf (pathEntries != [ ]) {
          PATH = hmExtLib.hm.shell.prependToVar ":" "PATH" pathEntries;
        })
      );
  };
}

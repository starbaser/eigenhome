# Translation layer: HM options → hjem primitives.
# Maps home.file → files, xdg.configFile → xdg.config.files, etc.
# Derives read-only HM values (home.username, xdg.configHome) from hjem config.
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkDefault
    mkIf
    ;

  # Translate a single HM file entry to a hjem file entry.
  # HM file entries have: enable, target, text, source, executable, recursive,
  # onChange, force, ignorelinks.
  # Hjem entries have: enable, type, target, text, source, executable, clobber.
  translateFileEntry = _name: entry: {
    inherit (entry) enable text source executable;
    clobber = entry.force;
  };

  # Filter to only enabled entries that have a source or text.
  translateFileSet = fileSet:
    mapAttrs translateFileEntry (filterAttrs (_: e: e.enable) fileSet);

  hasFiles = set: (filterAttrs (_: e: e.enable) set) != { };
in
{
  config = {
    # Derive read-only HM identity values from hjem config.
    # hjem sets config.user and config.directory in the per-user submodule.
    home = {
      username = config.user;
      homeDirectory = config.directory;
      profileDirectory = "/etc/profiles/per-user/${config.user}";
    };

    # Derive XDG paths from hjem's xdg.*.directory options.
    xdg = {
      configHome = config.xdg.config.directory;
      dataHome = config.xdg.data.directory;
      cacheHome = config.xdg.cache.directory;
      stateHome = config.xdg.state.directory;
    };

    # --- File translation ---

    # home.file → files (relative to home directory)
    files = mkIf (hasFiles config.home.file) (translateFileSet config.home.file);

    # xdg.configFile → xdg.config.files
    xdg.config.files =
      mkIf (hasFiles config.xdg.configFile) (translateFileSet config.xdg.configFile);

    # xdg.dataFile → xdg.data.files
    xdg.data.files =
      mkIf (hasFiles config.xdg.dataFile) (translateFileSet config.xdg.dataFile);

    # xdg.cacheFile → xdg.cache.files
    xdg.cache.files =
      mkIf (hasFiles config.xdg.cacheFile) (translateFileSet config.xdg.cacheFile);

    # xdg.stateFile → xdg.state.files
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
          PATH = lib.hm.shell.prependToVar ":" "PATH" pathEntries;
        })
      );
  };
}

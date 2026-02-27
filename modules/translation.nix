# Translation layer: HM options → hjem primitives.
# Maps home.file → files, xdg.configFile → xdg.config.files, etc.
# Derives read-only HM values (home.username, xdg.configHome) from hjem config.
{
  config,
  hmExtLib,
  lib,
  ...
}: let
  inherit
    (lib)
    filterAttrs
    listToAttrs
    mapAttrsToList
    mkIf
    ;

  # Translate an HM file entry value to hjem file entry value.
  translateFileValue = entry: {
    inherit (entry) enable;
    source = entry.source;
    executable =
      if entry.executable == true
      then true
      else false;
    clobber = entry.force;
  };

  # For home.file: use entry.target as key (relative to $HOME), since HM modules
  # often use absolute paths as attrset keys which file-type.nix resolves to
  # relative paths in `target`.
  translateHomeFileSet = fileSet:
    listToAttrs (
      mapAttrsToList (
        _name: entry: {
          name = entry.target;
          value = translateFileValue entry;
        }
      ) (filterAttrs (_: e: e.enable) fileSet)
    );

  # For xdg.*File: use the original attr key (already relative to the XDG dir).
  # entry.target is relative to $HOME (e.g. ".config/foo"), but hjem's
  # xdg.config.files expects keys relative to the XDG dir (e.g. "foo").
  translateXdgFileSet = fileSet:
    listToAttrs (
      mapAttrsToList (
        name: entry: {
          inherit name;
          value = translateFileValue entry;
        }
      ) (filterAttrs (_: e: e.enable) fileSet)
    );

  hasFiles = set: (filterAttrs (_: e: e.enable) set) != {};
in {
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
    files = mkIf (hasFiles config.home.file) (translateHomeFileSet config.home.file);

    xdg.config.files =
      mkIf (hasFiles config.xdg.configFile) (translateXdgFileSet config.xdg.configFile);

    xdg.data.files =
      mkIf (hasFiles config.xdg.dataFile) (translateXdgFileSet config.xdg.dataFile);

    xdg.cache.files =
      mkIf (hasFiles config.xdg.cacheFile) (translateXdgFileSet config.xdg.cacheFile);

    xdg.state.files =
      mkIf (hasFiles config.xdg.stateFile) (translateXdgFileSet config.xdg.stateFile);

    # --- Package translation ---
    packages = config.home.packages;

    # --- Session variable translation ---
    environment.sessionVariables = let
      vars = config.home.sessionVariables;
      pathEntries = config.home.sessionPath;
    in
      mkIf (vars != {} || pathEntries != []) (
        vars
        // (mkIf (pathEntries != []) {
          PATH = hmExtLib.hm.shell.prependToVar ":" "PATH" pathEntries;
        })
      );
  };
}

# Translation layer: HM options → eigenhome primitives.
# Maps home.file → files, xdg.configFile → xdg.config.files, etc.
# Derives read-only HM values (home.username, xdg.configHome) from eigenhome config.
{
  config,
  hmExtLib,
  lib,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    filterAttrs
    listToAttrs
    mapAttrsToList
    mkIf
    mkMerge
    nameValuePair
    ;

  translateFileValue = entry: {
    inherit (entry) enable;
    source = entry.source;
    executable = entry.executable == true;
    clobber = entry.force;
    recursive = entry.recursive or false;
    onChange = entry.onChange or "";
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
  # entry.target is relative to $HOME (e.g. ".config/foo"), but eigenhome's
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
      path = config.home.profileDirectory;
    };

    xdg = {
      configHome = config.xdg.config.directory;
      dataHome = config.xdg.data.directory;
      cacheHome = config.xdg.cache.directory;
      stateHome = config.xdg.state.directory;
    };

    files = mkIf (hasFiles config.home.file) (translateHomeFileSet config.home.file);

    xdg.config.files =
      mkIf (hasFiles config.xdg.configFile) (translateXdgFileSet config.xdg.configFile);

    xdg.data.files =
      mkIf (hasFiles config.xdg.dataFile) (translateXdgFileSet config.xdg.dataFile);

    xdg.cache.files =
      mkIf (hasFiles config.xdg.cacheFile) (translateXdgFileSet config.xdg.cacheFile);

    xdg.state.files =
      mkIf (hasFiles config.xdg.stateFile) (translateXdgFileSet config.xdg.stateFile);

    xdg.mime-apps = let
      ma = config.xdg.mimeApps;
    in
      mkIf ma.enable {
        default-applications = ma.defaultApplications;
        added-associations = ma.addedAssociations;
        removed-associations = ma.removedAssociations;
      };

    packages = config.home.packages;

    environment.sessionVariables = mkMerge [
      # home.sessionVariables + home.sessionPath
      (let
        vars = config.home.sessionVariables;
        pathEntries = config.home.sessionPath;
      in
        mkIf (vars != {} || pathEntries != []) (
          mkMerge [
            vars
            (lib.optionalAttrs (pathEntries != []) {
              PATH = hmExtLib.hm.shell.prependToVar ":" "PATH" pathEntries;
            })
          ]
        ))

      # home.sessionSearchVariables → colon-joined session variables
      (mkIf (config.home.sessionSearchVariables != {})
        (lib.mapAttrs (_: paths: concatStringsSep ":" (map toString paths))
          config.home.sessionSearchVariables))

      # home.language → locale environment variables
      (mkIf (config.home.language != {}) (let
        langMap = {
          base = "LANG";
          ctype = "LC_CTYPE";
          numeric = "LC_NUMERIC";
          time = "LC_TIME";
          collate = "LC_COLLATE";
          monetary = "LC_MONETARY";
          messages = "LC_MESSAGES";
          paper = "LC_PAPER";
          name = "LC_NAME";
          address = "LC_ADDRESS";
          telephone = "LC_TELEPHONE";
          measurement = "LC_MEASUREMENT";
        };
      in
        filterAttrs (_: v: v != null)
          (lib.mapAttrs' (k: v: nameValuePair (langMap.${k} or k) v)
            config.home.language)))
    ];
  };
}

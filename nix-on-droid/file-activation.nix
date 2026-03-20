# File deployment for nix-on-droid via build.activation.
#
# Generates a build.activation.eigenhomeFiles script that iterates all resolved
# file entries from eigenhome users and creates symlinks/copies. Activation scripts
# receive $DRY_RUN_CMD and $VERBOSE_ECHO from nix-on-droid's activation framework.
{
  config,
  lib,
  ...
}: let
  inherit (builtins) attrValues concatMap;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) filter;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatMapStringsSep optionalString;

  cfg = config.eigenhome;
  enabledUsers = filterAttrs (_: u: u.enable) cfg.users;

  userFiles = user: [
    user.files
    user.xdg.cache.files
    user.xdg.config.files
    user.xdg.data.files
    user.xdg.state.files
  ];

  allFiles =
    concatMap
    (u: concatMap (fileSet: filter (f: f.enable) (attrValues fileSet)) (userFiles u))
    (attrValues enabledUsers);

  mkFileCommand = file:
    if file.type == "symlink" && file.source != null
    then
      if file.clobber
      then ''
        $VERBOSE_ECHO "eigenhome: linking ${file.target}"
        $DRY_RUN_CMD mkdir -p "$(dirname '${file.target}')"
        $DRY_RUN_CMD ln -sfn '${file.source}' '${file.target}'
      ''
      else ''
        $VERBOSE_ECHO "eigenhome: linking ${file.target}"
        $DRY_RUN_CMD mkdir -p "$(dirname '${file.target}')"
        if [ -L '${file.target}' ] || [ ! -e '${file.target}' ]; then
          $DRY_RUN_CMD ln -sfn '${file.source}' '${file.target}'
        else
          $VERBOSE_ECHO "eigenhome: skipping ${file.target} (regular file exists, clobber=false)"
        fi
      ''
    else if file.type == "copy" && file.source != null
    then ''
      $VERBOSE_ECHO "eigenhome: copying ${file.target}"
      $DRY_RUN_CMD mkdir -p "$(dirname '${file.target}')"
      $DRY_RUN_CMD cp -f '${file.source}' '${file.target}'
      ${optionalString (file.permissions != null) "$DRY_RUN_CMD chmod ${file.permissions} '${file.target}'"}
      ${optionalString (file.executable && file.permissions == null) "$DRY_RUN_CMD chmod +x '${file.target}'"}
    ''
    else if file.type == "directory"
    then ''
      $VERBOSE_ECHO "eigenhome: creating directory ${file.target}"
      $DRY_RUN_CMD mkdir -p '${file.target}'
    ''
    else if file.type == "delete"
    then ''
      $VERBOSE_ECHO "eigenhome: deleting ${file.target}"
      $DRY_RUN_CMD rm -f '${file.target}'
    ''
    else "";

  activationScript = concatMapStringsSep "\n" mkFileCommand allFiles;
in {
  config = mkIf (allFiles != []) {
    build.activation.eigenhomeFiles = activationScript;
  };
}

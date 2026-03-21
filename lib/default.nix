{
  lib,
  pkgs,
}: let
  inherit (builtins) isList;
  inherit (lib.attrsets) filterAttrs optionalAttrs;
  inherit (lib.lists) toList;
  inherit (lib.strings) concatMapStringsSep;
  inherit (lib.types) attrsOf coercedTo either int listOf nullOr oneOf path str;
in rec {
  mkFileEntry = import ./file-type.nix {inherit lib pkgs;};

  # Inlined from nixpkgs nixos/modules/config/shells-environment.nix
  envVarType = attrsOf (nullOr (oneOf [(listOf (oneOf [int str path])) int str path]));

  listOrSingletonOf = type: coercedTo (either (listOf type) type) toList (listOf type);

  fileToJson = f:
    filterAttrs (_: v: v != null) {
      inherit
        (f)
        clobber
        gid
        permissions
        source
        target
        type
        uid
        ;
    }
    // optionalAttrs f.recursive {recursive = true;};

  toEnv = env:
    if isList env
    then concatMapStringsSep ":" toString env
    else toString env;
}

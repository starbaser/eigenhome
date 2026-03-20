# Activation DAG runner: generates a topo-sorted bash script from home.activation
# entries and writes it as a file managed by hjem's linker.
#
# HM's built-in lifecycle phases (writeBoundary, installPackages, etc.) are
# filtered out since hjem handles file linking and package installation natively.
# The remaining entries (dconf, gpg, font-cache, user-defined) are assembled
# into an executable script at ~/.local/share/eigenhome/activate.
{
  config,
  hmExtLib,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    filter
    mkIf
    ;

  # HM built-in activation phases that conflict with hjem's linker or are
  # irrelevant outside HM's generation model.
  filteredPhases = lib.genAttrs [
    "writeBoundary"
    "installPackages"
    "checkLinkTargets"
    "linkGeneration"
    "checkFilesChanged"
    "onFilesChange"
    "createXdgUserDirectories"
    "reloadSystemd"
  ] (_: true);

  activation = config.home.activation;

  sortedEntries = let
    sorted = hmExtLib.hm.dag.topoSort activation;
  in
    if sorted ? result
    then sorted.result
    else
      builtins.abort (
        "eigenhome: Dependency cycle in home.activation: "
        + builtins.toJSON sorted
      );

  userEntries = filter (entry: !(filteredPhases ? ${entry.name})) sortedEntries;
  hasUserEntries = userEntries != [];

  activationScript = pkgs.writeShellScript "eigenhome-activate" ''
    set -euo pipefail

    # Minimal HM-compatible shell helpers for activation scripts.
    _iNote() { local fmt="$1"; shift; printf "note: $fmt\n" "$@"; }
    _iWarn() { local fmt="$1"; shift; printf "warning: $fmt\n" "$@" >&2; }
    _iError() { local fmt="$1"; shift; printf "error: $fmt\n" "$@" >&2; }
    verboseEcho() { :; }

    run() {
      if [[ "$1" == "--silence" ]]; then
        shift
        "$@" > /dev/null 2>&1
      elif [[ "$1" == "--quiet" ]]; then
        shift
        "$@" > /dev/null
      else
        "$@"
      fi
    }

    # HM activation scripts expect these variables.
    # newGenPath/oldGenPath are HM-specific; set empty for compatibility.
    export newGenPath=""
    export oldGenPath=""
    export genProfilePath=""
    export DRY_RUN_CMD=""
    export DRY_RUN_NULL=/dev/null
    export VERBOSE_ECHO=verboseEcho
    export VERBOSE_ARG=""
    export VERBOSE_RUN=""

    _iNote "Running eigenhome activation scripts"

    ${concatStringsSep "\n" (map (entry: ''
        _iNote "Activating %s" "${entry.name}"
        ${entry.data}
      '')
      userEntries)}

    _iNote "eigenhome activation complete"
  '';
in {
  config = mkIf hasUserEntries {
    xdg.data.files."eigenhome/activate" = {
      source = activationScript;
      executable = true;
    };
  };
}

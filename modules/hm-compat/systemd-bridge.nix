# Systemd bridge: translates HM's systemd.user.* INI-section options into
# hjem's systemd.units entries.
#
# HM modules write INI-section style:   { Unit.Description = "..."; Service.ExecStart = "..."; }
# Hjem's systemd.nix uses NixOS types:  { description = "..."; serviceConfig.ExecStart = "..."; }
#
# Rather than converting between these incompatible schemas, the bridge generates INI
# text directly and inject into hjem's internal systemd.units option — the
# same data store that hjem's own unit generation feeds into.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    filterAttrs
    isBool
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    toList
    types
    ;

  cfg = config.systemd.user;

  # Freeform unit type matching HM's INI-section format.
  # Accepts { Unit = { Description = "..."; }; Service = { ExecStart = "..."; }; }
  primitive = types.oneOf [
    types.bool
    types.int
    types.str
    types.path
    types.package
  ];

  unitModule = types.submodule {
    freeformType =
      types.attrsOf (types.attrsOf (types.either primitive (types.listOf primitive)));
  };

  # INI text generation matching HM's toSystemdIni.
  toSystemdIni = lib.generators.toINI {
    listsAsDuplicateKeys = true;
    mkKeyValue = key: value: let
      value' =
        if isBool value
        then
          (
            if value
            then "true"
            else "false"
          )
        else toString value;
    in "${key}=${value'}";
  };

  cleanUnit = def:
    filterAttrs (_: v: v != {}) (
      mapAttrs (_: filterAttrs (_: v: v != null && v != [])) def
    );

  toUnitEntry = name: type: def: let
    install = def.Install or {};
    wantedBy =
      if install ? WantedBy
      then toList install.WantedBy
      else [];
    requiredBy =
      if install ? RequiredBy
      then toList install.RequiredBy
      else [];
  in {
    text = toSystemdIni (cleanUnit (removeAttrs def ["Install"]));
    inherit wantedBy requiredBy;
  };

  mkUnits = type: defs:
    mapAttrs' (n: v: nameValuePair "${n}.${type}" (toUnitEntry n type v)) defs;

  hasAnyUnits =
    cfg.services
    != {}
    || cfg.timers != {}
    || cfg.paths != {}
    || cfg.sockets != {}
    || cfg.targets != {}
    || cfg.slices != {};
in {
  options.systemd.user = {
    enable =
      mkEnableOption "systemd user service management"
      // {
        default = pkgs.stdenv.isLinux;
      };

    services = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user service units.";
    };

    timers = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user timer units.";
    };

    paths = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user path units.";
    };

    sockets = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user socket units.";
    };

    targets = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user target units.";
    };

    slices = mkOption {
      type = types.attrsOf unitModule;
      default = {};
      description = "Definition of systemd per-user slice units.";
    };

    sessionVariables = mkOption {
      type = types.attrsOf (types.either types.int types.str);
      default = {};
      description = "Environment variables for the systemd user session via environment.d.";
    };

    startServices = mkOption {
      type = types.either types.bool (
        types.enum [
          "suggest"
          "sd-switch"
        ]
      );
      default = true;
      description = "Accepted for compatibility. Service switching is handled by the NixOS activation module.";
    };

    systemctlPath = mkOption {
      type = types.str;
      default = "";
      description = "Accepted for compatibility. Not used by eigenhome.";
    };

    tmpfiles.rules = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Accepted for compatibility. Not used by eigenhome.";
    };
  };

  config = mkIf cfg.enable {
    systemd.units = mkIf hasAnyUnits (mkMerge [
      (mkUnits "service" cfg.services)
      (mkUnits "timer" cfg.timers)
      (mkUnits "path" cfg.paths)
      (mkUnits "socket" cfg.sockets)
      (mkUnits "target" cfg.targets)
      (mkUnits "slice" cfg.slices)
    ]);

    environment.sessionVariables = mkIf (cfg.sessionVariables != {}) cfg.sessionVariables;
  };
}

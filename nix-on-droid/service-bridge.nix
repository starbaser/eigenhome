# User submodule: translates systemd service definitions to nix-on-droid patterns.
#
# Reads systemd.user.services from hjem-compat's systemd-bridge (if loaded) and:
#   a) Simple/exec services → wrapper scripts (nod-<name>) added to packages
#   b) Auto-start services  → sourceable script at xdg.data.files
#   c) Oneshot services     → build.activation entries via _nodOneshotActivations
#   d) Unsupported types    → warnings
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames hasAttr isList;
  inherit (lib.attrsets) attrByPath filterAttrs mapAttrs' mapAttrsToList nameValuePair;
  inherit (lib.lists) any concatLists optional toList;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (lib.types) attrsOf str;

  # Access systemd.user.services from hjem-compat's bridge if loaded.
  # config.systemd won't have a "user" key.
  hasUserSection = hasAttr "user" config.systemd;
  services =
    if hasUserSection
    then attrByPath ["systemd" "user" "services"] {} config
    else {};

  getType = svc: attrByPath ["Service" "Type"] "simple" svc;

  simpleServices = filterAttrs (_: svc: let
    t = getType svc;
  in
    t == "simple" || t == "exec")
  services;

  oneshotServices = filterAttrs (_: svc: getType svc == "oneshot") services;

  mkWrapper = name: svc: let
    rawExecStart = svc.Service.ExecStart or "true";
    execStart =
      if isList rawExecStart
      then toString (builtins.head rawExecStart)
      else toString rawExecStart;
    envVars = toList (svc.Service.Environment or []);
    workDir = svc.Service.WorkingDirectory or null;
    description = attrByPath ["Unit" "Description"] name svc;
  in
    pkgs.writeShellScriptBin "nod-${name}" ''
      # ${description}
      ${concatMapStringsSep "\n" (e: "export ${toString e}") envVars}
      ${optionalString (workDir != null) "cd \"${toString workDir}\""}
      exec ${execStart}
    '';

  wrapperPackages = mapAttrsToList mkWrapper simpleServices;

  autostartServices = filterAttrs (_: svc: let
    wantedBy = toList (attrByPath ["Install" "WantedBy"] [] svc);
  in
    any (t: t == "default.target" || t == "graphical-session.target") wantedBy)
  simpleServices;

  autostartScript =
    concatMapStringsSep "\n"
    (name: ''pgrep -f "nod-${name}" >/dev/null 2>&1 || { nod-${name} & disown; }'')
    (attrNames autostartServices);

  hasSimple = simpleServices != {};
  hasAutostart = autostartServices != {};
  hasOneshot = oneshotServices != {};

  checkUnsupported = type: let
    units = attrByPath ["systemd" "user" type] {} config;
  in
    optional (units != {})
    "nix-on-droid: systemd.user.${type} is not supported. Defined units (${toString (attrNames units)}) will be ignored.";
in {
  options._nodOneshotActivations = mkOption {
    type = attrsOf str;
    default = {};
    internal = true;
    description = "Oneshot service activation scripts for nix-on-droid.";
  };

  config = {
    packages = mkIf hasSimple wrapperPackages;

    xdg.data.files."hjem-compat/nod-autostart.sh" = mkIf hasAutostart {
      text = autostartScript;
      executable = true;
    };

    _nodOneshotActivations = mkIf hasOneshot (
      mapAttrs'
      (name: svc: let
        rawExecStart = svc.Service.ExecStart or "true";
        commands =
          if isList rawExecStart
          then map toString rawExecStart
          else [toString rawExecStart];
        envVars = toList (svc.Service.Environment or []);
        workDir = svc.Service.WorkingDirectory or null;
      in
        nameValuePair "hjemOneshot-${name}" ''
          $VERBOSE_ECHO "hjem: running oneshot service ${name}"
          ${concatMapStringsSep "\n" (e: "export ${toString e}") envVars}
          ${optionalString (workDir != null) "cd \"${toString workDir}\""}
          ${concatMapStringsSep "\n" (cmd: "$DRY_RUN_CMD ${cmd}") commands}
        '')
      oneshotServices
    );

    warnings = concatLists [
      (checkUnsupported "timers")
      (checkUnsupported "paths")
      (checkUnsupported "sockets")
      (checkUnsupported "targets")
      (checkUnsupported "slices")
    ];
  };
}

# dconf bridge: applies dconf.settings via a systemd oneshot service.
#
# HM modules (Stylix gnome.nix, etc.) write dconf key-value pairs to
# config.dconf.settings. This bridge serializes them to a dconf keyfile
# and creates a systemd user service that loads them via `dconf load /`.
#
# The option is declared in cross-module-stubs.nix — this module is config-only.
# The systemd service feeds into systemd-bridge.nix for hjem translation.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mapAttrsToList mkIf;
  cfg = config.dconf;

  # Serialize a Nix value to GVariant text format for dconf keyfiles.
  formatGVariant = v:
    if builtins.isString v
    then "'${builtins.replaceStrings ["'"] ["\\'"] v}'"
    else if builtins.isBool v
    then
      (
        if v
        then "true"
        else "false"
      )
    else if builtins.isInt v
    then toString v
    else if builtins.isFloat v
    then builtins.toJSON v
    else if builtins.isList v
    then "[${concatStringsSep ", " (map formatGVariant v)}]"
    else builtins.toJSON v;

  # Generate one INI section per dconf path.
  toKeyfileSection = path: settings:
    "[${path}]\n"
    + concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${formatGVariant v}") settings)
    + "\n";

  keyfileText = concatStringsSep "\n" (
    mapAttrsToList toKeyfileSection cfg.settings
  );

  keyfile = pkgs.writeText "hjem-compat-dconf.ini" keyfileText;

  loadScript = pkgs.writeShellScript "hjem-compat-dconf-load" ''
    ${pkgs.dconf}/bin/dconf load / < ${keyfile}
  '';
in {
  config = mkIf (cfg.enable && cfg.settings != {}) {
    systemd.user.services.hjem-compat-dconf-load = {
      Unit = {
        Description = "Apply dconf settings (hjem-compat)";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${loadScript}";
        RemainAfterExit = true;
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}

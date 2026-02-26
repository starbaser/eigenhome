# Stub declarations for cross-module dependencies that HM program modules reference.
# Without these, modules like git.nix crash when accessing config.accounts.email.*
# or config.programs.gpg.package.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkIf mkOption types;
in
{
  options = {
    # HM's accounts module — git.nix reads config.accounts.email.accounts unconditionally.
    # Stub with an empty default so filterAttrs over it returns {}.
    accounts.email.accounts = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Stub for HM accounts module compatibility.";
    };

    # HM's gpg module — git.nix reads config.programs.gpg.package for signing defaults.
    programs.gpg.package = lib.mkPackageOption pkgs "gnupg" { };

    # HM's systemd.user.* — bridge to hjem's systemd.* (which is already per-user).
    # HM modules write to systemd.user.services, hjem has systemd.services.
    systemd.user = {
      services = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Stub for HM systemd.user.services (bridged to hjem systemd.services).";
      };
      timers = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Stub for HM systemd.user.timers (bridged to hjem systemd.timers).";
      };
    };

    # Darwin launchd stubs — HM modules conditionally write to these.
    launchd.agents = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Stub for HM launchd.agents (not supported on Linux).";
    };
  };

  # Bridge systemd.user.* → hjem's systemd.* when content exists.
  config = {
    systemd.services =
      mkIf (config.systemd.user.services != { }) config.systemd.user.services;
    systemd.timers =
      mkIf (config.systemd.user.timers != { }) config.systemd.user.timers;
  };
}

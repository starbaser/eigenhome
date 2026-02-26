# Stub declarations for cross-module dependencies that HM program modules reference.
# Without these, modules like git.nix crash when accessing config.accounts.email.*
# or config.programs.gpg.package.
{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options = {
    # HM modules set meta.maintainers = []; — accept and discard.
    meta = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Module metadata (accepted for compatibility, not used).";
    };

    # HM's accounts module — git.nix reads config.accounts.email.accounts unconditionally.
    accounts.email.accounts = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Stub for HM accounts module compatibility.";
    };

    # HM's gpg module — git.nix reads config.programs.gpg.package for signing defaults.
    programs.gpg.package = lib.mkPackageOption pkgs "gnupg" { };

    # HM's systemd.user.* — accepts writes from HM modules.
    # Not bridged to hjem's systemd.* to avoid type conflicts.
    # Users who need systemd services should configure them through hjem directly.
    systemd.user = {
      services = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Stub for HM systemd.user.services.";
      };
      timers = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Stub for HM systemd.user.timers.";
      };
    };

    # Darwin launchd stubs — HM modules conditionally write to these.
    launchd.agents = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Stub for HM launchd.agents (not supported on Linux).";
    };
  };
}

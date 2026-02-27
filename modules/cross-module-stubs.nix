# Stub declarations for cross-module dependencies that HM program modules reference.
# Without these, modules like git.nix crash when accessing config.accounts.email.*
# or config.programs.gpg.package.
{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options = {
    # HM modules set meta.maintainers = []; — accept and discard.
    meta = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Module metadata (accepted for compatibility, not used).";
    };

    # HM's accounts module — git.nix reads config.accounts.email.accounts unconditionally.
    accounts.email.accounts = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM accounts module compatibility.";
    };

    # HM's gpg module — git.nix reads config.programs.gpg.package for signing defaults.
    programs.gpg.package = lib.mkPackageOption pkgs "gnupg" {};

    # HM's git module reads config.programs.${name}.enable for external diff tools.
    # These would normally be defined by their own HM modules (delta.nix, etc.).
    programs.delta.enable = lib.mkEnableOption "delta";
    programs.diff-so-fancy.enable = lib.mkEnableOption "diff-so-fancy";
    programs.difftastic.enable = lib.mkEnableOption "difftastic";
    programs.diff-highlight.enable = lib.mkEnableOption "diff-highlight";
    programs.patdiff.enable = lib.mkEnableOption "patdiff";
    programs.riff.enable = lib.mkEnableOption "riff";

    # Darwin launchd stubs — HM modules conditionally write to these.
    launchd.agents = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM launchd.agents (not supported on Linux).";
    };
  };
}

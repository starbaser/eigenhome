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

    # dconf — GTK/GNOME theming modules (Stylix, etc.) set dconf settings.
    # Accepted here; actual application is handled by dconf-bridge.nix.
    dconf.settings = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = {};
      description = "dconf settings for inter-module communication and GTK theming.";
    };
    dconf.enable = lib.mkEnableOption "dconf settings management" // { default = true; };

    # HM's home.pointerCursor — cursor theme configuration.
    home.pointerCursor = mkOption {
      type = types.nullOr (types.submodule {
        freeformType = types.attrsOf types.anything;
      });
      default = null;
      description = "Cursor theme configuration (translated to hjem cursor files).";
    };

    # i18n — input method framework (fcitx5, etc.). Stylix's fcitx5 target
    # writes here even when disabled (mkIf false still requires option path).
    i18n = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
      };
      default = {};
      description = "Input method config (accepted for compat).";
    };

    # xsession — X11 session config (accept and discard on Wayland).
    xsession = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
      };
      default = {};
      description = "X11 session config (accepted, not used on Wayland).";
    };

    # Fontconfig defaults — consumed by fontconfig-bridge.nix.
    fonts.fontconfig = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
      };
      default = {};
      description = "Fontconfig defaults (translated to conf.d XML by fontconfig-bridge).";
    };

    # X resources — accept and discard on Wayland.
    xresources = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
      };
      default = {};
      description = "Stub for HM xresources namespace (not bridged on Wayland).";
    };

    # Wayland compositor options — safety net for disabled targets.
    wayland = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM wayland.* namespace (not bridged).";
    };

    # HM non-systemd services — safety net for disabled targets.
    # Distinct from systemd.user.services (declared in systemd-bridge.nix).
    services = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM services.* namespace (not bridged).";
    };

    # Darwin stubs — HM modules conditionally write to these on macOS.
    launchd.agents = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM launchd.agents (not supported on Linux).";
    };

    targets.darwin.defaults = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM targets.darwin.defaults (not supported on Linux).";
    };
  };
}

# Stub declarations for cross-module dependencies that HM program modules reference.
# Without these, modules like git.nix crash when accessing config.accounts.email.*
# or config.programs.gpg.package.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
in {
  config = {
    # HM email program modules (mbsync, msmtp, etc.) declare accounts.email.accounts
    # without a default value. Provide an empty default so the option has a value
    # when no email accounts are configured.
    accounts.email.accounts = lib.mkDefault {};
  };

  options = {
    # HM modules set meta.maintainers = []; — accept and discard.
    meta = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Module metadata (accepted for compatibility, not used).";
    };

    # HM's gpg module — git.nix reads config.programs.gpg.package for signing defaults.
    programs.gpg.package = lib.mkPackageOption pkgs "gnupg" {};

    programs.gpg.homedir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.gnupg";
      description = "GnuPG home directory path.";
    };

    programs.home-manager.enable = lib.mkEnableOption "home-manager";
    programs.home-manager.package = lib.mkPackageOption pkgs "home-manager" {};

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
      description = "Cursor theme configuration (translated to eigenhome cursor files).";
    };

    # nixpkgs — HM/Stylix modules set nixpkgs.overlays in their module context.
    # Accepted as a sink; overlays are applied at the NixOS layer, not eigenhome.
    nixpkgs = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM nixpkgs namespace (overlays applied at NixOS level).";
    };

    # i18n — input method framework (fcitx5, etc.). Stylix's fcitx5 target
    # writes here even when disabled (mkIf false still requires option path).
    i18n = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Input method config (accepted for compat).";
    };


    # Fontconfig defaults — consumed by fontconfig-bridge.nix.
    fonts.fontconfig = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Fontconfig defaults (translated to conf.d XML by fontconfig-bridge).";
    };

    # xfconf — XFCE settings. Stylix's XFCE target writes here even when disabled.
    xfconf = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "XFCE xfconf settings (accepted for compat).";
    };

    # X resources — accept and discard on Wayland.
    xresources = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM xresources namespace (not bridged on Wayland).";
    };


    # dbus — ghostty and other modules set dbus.packages.
    dbus = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Stub for HM dbus namespace (accepted for compat).";
    };

    # mozilla — browser modules (librewolf, floorp) set native messaging hosts.
    # Uses submodule so user-imported HM mozilla-messaging-hosts.nix can
    # extend with typed sub-options without conflicting.
    mozilla = mkOption {
      type = types.submodule {freeformType = types.attrsOf types.anything;};
      default = {};
      description = "Mozilla native messaging host config (extended by HM mozilla module).";
    };

    # submoduleSupport — HM's home-manager.nix reads this to gate behavior.
    submoduleSupport.enable = mkOption {
      type = types.bool;
      default = false;
      description = "HM submodule support flag (accepted for compat).";
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

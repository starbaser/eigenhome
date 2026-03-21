# Cursor bridge: translates HM's home.pointerCursor into eigenhome cursor artifacts.
#
# HM modules (Stylix cursor.nix, etc.) set config.home.pointerCursor with
# { name, package, size, x11.enable, gtk.enable }. This bridge generates
# the cursor index.theme and environment variables that make the cursor
# theme active under Wayland and X11.
#
# The option is declared in cross-module-stubs.nix — this module is config-only.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.home.pointerCursor;
in {
  config = mkIf (cfg != null && cfg ? name) {
    packages = lib.optional (cfg ? package && cfg.package != null) cfg.package;

    files.".icons/default/index.theme".text = ''
      [Icon Theme]
      Name=Default
      Comment=Default Cursor Theme
      Inherits=${cfg.name}
    '';

    environment.sessionVariables = {
      XCURSOR_THEME = cfg.name;
      XCURSOR_SIZE = toString (cfg.size or 24);
    };
  };
}

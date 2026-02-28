# Fontconfig bridge: translates fonts.fontconfig.defaultFonts into fontconfig XML.
#
# Stylix's fontconfig target sets config.fonts.fontconfig.defaultFonts with
# lists of font family names per category (monospace, sansSerif, serif, emoji).
# This bridge generates <prefer> aliases so fc-match resolves to the configured
# fonts without requiring HM's profile-based fontconfig module.
#
# The option is declared in cross-module-stubs.nix — this module is config-only.
{
  config,
  lib,
  ...
}: let
  inherit (lib) concatStringsSep mkIf optionalString;
  cfg = config.fonts.fontconfig;
  defaults = cfg.defaultFonts or {};
  hasDefaults = defaults != {};

  mkAlias = generic: families: ''
    <alias binding="same">
      <family>${generic}</family>
      <prefer>
        ${concatStringsSep "\n      " (map (f: "<family>${f}</family>") families)}
      </prefer>
    </alias>
  '';

  xml = ''
    <?xml version='1.0'?>
    <!DOCTYPE fontconfig SYSTEM '/usr/share/xml/fontconfig/fonts.dtd'>
    <fontconfig>
      ${optionalString (defaults ? monospace) (mkAlias "monospace" defaults.monospace)}
      ${optionalString (defaults ? sansSerif) (mkAlias "sans-serif" defaults.sansSerif)}
      ${optionalString (defaults ? serif) (mkAlias "serif" defaults.serif)}
      ${optionalString (defaults ? emoji) (mkAlias "emoji" defaults.emoji)}
    </fontconfig>
  '';
in {
  config = mkIf hasDefaults {
    xdg.config.files."fontconfig/conf.d/60-hjem-compat-defaults.conf".text = xml;
  };
}

# HM service module loader — dynamic discovery of services.* namespace.
#
# Mirrors programs-stubs.nix but targets the HM services directory.
# All discovered service modules are loaded via wrapHmModule. Darwin modules
# are safe to include — they use mkIf guards that make them no-ops on Linux.
#
# No freeform stubs needed here (thirdParty is empty). The old freeform
# services sink in cross-module-stubs.nix is removed in favor of these
# typed options sourced directly from HM.
#
# Services already declared with typed options elsewhere are excluded via
# alreadyDeclared. Currently none — all services live in this module.
{hmSrc, wrapHmModule}:
{lib, ...}: let
  # Services declared with typed options in other modules — skip these.
  alreadyDeclared = [
    # Declares wayland.windowManager.{sway,hyprland,...} and xsession.windowManager.*
    # typed options that conflict with the freeform stubs in cross-module-stubs.nix.
    # Window manager programs are already handled by programs-stubs.nix (hyprland, etc.).
    "window-managers"
  ];

  # No known third-party service modules (not present in HM source).
  thirdParty = [];

  # Discover all HM service modules from source via readDir.
  # Accepts both file.nix and directory/default.nix layouts.
  discoverModules = dir:
    lib.pipe (builtins.readDir dir) [
      (lib.filterAttrs (name: type:
        (type == "regular" && lib.hasSuffix ".nix" name)
        || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))))
      (lib.mapAttrsToList (name: type:
        if type == "regular" then lib.removeSuffix ".nix" name else name))
    ];

  discovered = discoverModules "${hmSrc}/modules/services";

  # Filter out services already declared with typed options elsewhere.
  needsHandling = builtins.filter (p: !(builtins.elem p alreadyDeclared)) discovered;

  # Resolve HM module path: file.nix or directory/default.nix.
  # All discovered modules exist by construction — never returns null.
  hmModulePath = name: let
    filePath = "${hmSrc}/modules/services/${name}.nix";
    dirPath = "${hmSrc}/modules/services/${name}/default.nix";
  in
    if builtins.pathExists filePath then filePath
    else dirPath;
in {
  imports = map (p: wrapHmModule (hmModulePath p)) needsHandling;

  options.services = lib.genAttrs thirdParty (_: lib.mkOption {
    type = lib.types.submodule {freeformType = lib.types.attrsOf lib.types.anything;};
    default = {};
    description = "Freeform stub for HM service compat.";
  });
}

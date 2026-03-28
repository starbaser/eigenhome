# HM program module loader with freeform fallback.
#
# Stylix (and other meta-modules) import ALL their target modules, even
# disabled ones. Each target writes to programs.X.* wrapped in mkIf false,
# but the module system still requires the option path to exist.
#
# For programs with upstream HM modules, we import the actual module via
# wrapHmModule — this provides typed options AND the config block that
# generates home.file entries (CSS snippets, appearance.json, etc.).
#
# For programs without HM modules (third-party: nixcord, nixvim, spicetify,
# and others), we declare freeform submodule stubs to accept their option
# writes.
#
# Programs already declared with typed options elsewhere are excluded:
#   shell-stubs.nix: bash, zsh, fish, ion, nushell
#   cross-module-stubs.nix: gpg, delta, diff-so-fancy, difftastic,
#                           diff-highlight, patdiff, riff
#
# Module discovery uses builtins.readDir against the HM programs directory —
# no hardcoded list required. Third-party programs (not present in HM source)
# receive freeform stubs instead.
{hmSrc, wrapHmModule}:
{lib, ...}: let
  inherit (lib) genAttrs mkOption types;

  # Programs declared with typed options in other modules — skip these.
  # Also excludes modules that cause infinite recursion via self-referential
  # config.programs.zsh.enable checks inside freeform submodule definitions.
  alreadyDeclared = [
    "bash"
    "zsh"
    "fish"
    "ion"
    "nushell"
    "gpg"
    "delta"
    "diff-so-fancy"
    "difftastic"
    "diff-highlight"
    "patdiff"
    "riff"
    "home-manager"
    # These modules write to programs.zsh.initContent conditioned on
    # config.programs.zsh.enable, or extend programs.zsh with typed sub-options,
    # creating a self-referential cycle in the freeform zsh submodule.
    "powerline-go"
    "gnome-terminal"
    "termite"
    # These modules extend programs.zsh with typed sub-options (programs.zsh.antidote,
    # programs.zsh.zplug) which conflicts with eigenhome's freeform zsh stub.
    "antidote"
    "zplug"
    # himalaya uses mkRemovedOptionModule for ["services" "himalaya-watch" "enable"],
    # which tries to access services.himalaya-watch.enable via lib.getAttrFromPath —
    # fails on eigenhome's freeform services stub that returns {} for unknown keys.
    "himalaya"
  ];

  # Third-party programs that write to programs.* but have no upstream HM
  # module — verified by cross-referencing against HM source at refactor time.
  thirdParty = [
    "dank-material-shell"
    "dconf"
    "hyprland"
    "nixcord"
    "nixvim"
    "noctalia-shell"
    "nvf"
    "regreet"
    "spicetify"
    "zen-browser"
  ];

  # Discover all HM program modules from source via readDir.
  # Accepts both file.nix and directory/default.nix layouts.
  discoverModules = dir:
    lib.pipe (builtins.readDir dir) [
      (lib.filterAttrs (name: type:
        (type == "regular" && lib.hasSuffix ".nix" name)
        || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))))
      (lib.mapAttrsToList (name: type:
        if type == "regular" then lib.removeSuffix ".nix" name else name))
    ];

  discovered = discoverModules "${hmSrc}/modules/programs";

  # Filter out programs already declared with typed options elsewhere.
  needsHandling = builtins.filter (p: !(builtins.elem p alreadyDeclared)) discovered;

  # Resolve HM module path: file.nix or directory/default.nix.
  # All discovered modules exist by construction — never returns null.
  hmModulePath = name: let
    filePath = "${hmSrc}/modules/programs/${name}.nix";
    dirPath = "${hmSrc}/modules/programs/${name}/default.nix";
  in
    if builtins.pathExists filePath then filePath
    else dirPath;
in {
  imports = map (p: wrapHmModule (hmModulePath p)) needsHandling;

  options.programs = genAttrs thirdParty (_: mkOption {
    type = types.submodule {freeformType = types.attrsOf types.anything;};
    default = {};
    description = "Freeform stub for HM program compat.";
  });
}

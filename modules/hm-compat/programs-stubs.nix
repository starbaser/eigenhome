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
# For programs without HM modules (third-party: nixcord, nixvim, spicetify),
# we declare freeform submodule stubs to accept their option writes.
#
# Programs already declared with typed options elsewhere are excluded:
#   shell-stubs.nix: bash, zsh, fish, ion, nushell
#   cross-module-stubs.nix: gpg, delta, diff-so-fancy, difftastic,
#                           diff-highlight, patdiff, riff
#   firefox-config flake: firefox
{hmSrc, wrapHmModule}:
{lib, ...}: let
  inherit (lib) genAttrs mkOption types;

  # Programs declared with typed options in other modules — skip these.
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
    "firefox"
  ];

  # All programs that Stylix, common HM meta-modules, and cross-referenced
  # HM program modules write to. Programs with upstream HM modules are
  # auto-imported; the rest get freeform stubs.
  allPrograms = [
    "alacritty"
    "anki"
    "ashell"
    "bat"
    "bemenu"
    "broot"
    "btop"
    "cava"
    "cavalier"
    "chromium"
    "dank-material-shell"
    "dconf"
    "direnv"
    "emacs"
    "floorp"
    "foliate"
    "foot"
    "fuzzel"
    "fzf"
    "ghostty"
    "git"
    "gitui"
    "halloy"
    "helix"
    "hyprland"
    "hyprlock"
    "hyprpanel"
    "i3bar-river"
    "jjui"
    "k9s"
    "kitty"
    "kubecolor"
    "lazygit"
    "mangohud"
    "micro"
    "mpv"
    "ncspot"
    "neovide"
    "neovim"
    "nixcord"
    "nixvim"
    "librewolf"
    "noctalia-shell"
    "nvf"
    "obsidian"
    "opencode"
    "qutebrowser"
    "regreet"
    "rio"
    "rofi"
    "sioyek"
    "spicetify"
    "spotify-player"
    "starship"
    "swaylock"
    "tmux"
    "tofi"
    "vesktop"
    "vicinae"
    "vim"
    "vivid"
    "vscode"
    "waybar"
    "wayprompt"
    "wezterm"
    "wofi"
    "yazi"
    "zathura"
    "zed-editor"
    "zellij"
    "zen-browser"
  ];

  needsHandling = builtins.filter (p: !(builtins.elem p alreadyDeclared)) allPrograms;

  # Resolve HM module path: file.nix or directory/default.nix.
  hmModulePath = name: let
    filePath = "${hmSrc}/modules/programs/${name}.nix";
    dirPath = "${hmSrc}/modules/programs/${name}/default.nix";
  in
    if builtins.pathExists filePath then filePath
    else if builtins.pathExists dirPath then dirPath
    else null;

  # Split: programs with upstream HM modules vs. third-party stubs.
  withHmModule = builtins.filter (p: hmModulePath p != null) needsHandling;
  withoutHmModule = builtins.filter (p: hmModulePath p == null) needsHandling;
in {
  imports = map (p: wrapHmModule (hmModulePath p)) withHmModule;

  options.programs = genAttrs withoutHmModule (_: mkOption {
    type = types.submodule {freeformType = types.attrsOf types.anything;};
    default = {};
    description = "Freeform stub for HM program compat.";
  });
}

# Freeform program stubs for HM program namespaces.
#
# Stylix (and other meta-modules) import ALL their target modules, even
# disabled ones. Each target writes to programs.X.* wrapped in mkIf false,
# but the module system still requires the option path to exist. This
# module declares freeform submodule stubs for all known program namespaces.
#
# Programs already declared with typed options elsewhere are excluded:
#   shell-stubs.nix: bash, zsh, fish, ion, nushell
#   cross-module-stubs.nix: gpg, delta, diff-so-fancy, difftastic,
#                           diff-highlight, patdiff, riff
#   firefox-config flake: firefox
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

  # All programs that Stylix and common HM meta-modules write to.
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
    "emacs"
    "foliate"
    "foot"
    "fuzzel"
    "fzf"
    "ghostty"
    "gitui"
    "halloy"
    "helix"
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
    "nixvim"
    "noctalia-shell"
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

  needsStub = builtins.filter (p: !(builtins.elem p alreadyDeclared)) allPrograms;
in {
  options.programs = genAttrs needsStub (_: mkOption {
    type = types.submodule {freeformType = types.attrsOf types.anything;};
    default = {};
    description = "Freeform stub for HM program compat.";
  });
}

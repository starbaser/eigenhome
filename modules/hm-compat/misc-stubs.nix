# HM misc module loader — loads cross-cutting modules from modules/misc/.
#
# HM's modules/modules.nix explicitly lists misc/* modules (they aren't
# glob-discovered like programs/ and services/). These include coordination
# modules (ssh_auth_sock, shell, specialisation) that HM service and program
# modules depend on, plus GUI theming (gtk, qt, vte) that Stylix targets.
#
# Modules already handled natively by eigenhome are excluded:
#   home-options.nix: home-environment, files, version, uninstall, news
#   xdg-options.nix: xdg, xdg-user-dirs, xdg-mime-apps, xdg-desktop-entries,
#                    xdg-mime, xdg-system-dirs, xdg-portal, xdg-autostart,
#                    xdg-terminal-exec
#   shell-stubs.nix / shell-bridge.nix: shell
#   cross-module-stubs.nix: dconf, submodule-support, nixpkgs, xfconf,
#                           fontconfig, mozilla-messaging-hosts, pam
#   dconf-bridge.nix: dconf
#   fontconfig-bridge.nix: fontconfig
#   config-lib.nix: lib
#   systemd-bridge.nix: tmpfiles
#   warnings.nix: debug
#   activation-runner.nix: specialisation
{hmSrc, wrapHmModule}:
{lib, ...}: let
  # Modules handled by eigenhome's own implementations — skip these.
  alreadyHandled = [
    "dconf"
    "debug"
    "fontconfig"
    "lib"
    "mozilla-messaging-hosts"
    "news"
    "nix"
    "nixpkgs"
    "nixpkgs-disabled"
    "nix-remote-build"
    "pam"
    "shell"
    "specialisation"
    "submodule-support"
    "tmpfiles"
    "uninstall"
    "version"
    # vte reads config.programs.zsh.enableVteIntegration — cycle through
    # shell-bridge → programs.zsh → vte → programs.zsh.
    "vte"
    # gtk and qt declare typed options (gtk.enable, qt.enable) that conflict
    # with Stylix's own declarations of the same options.
    "gtk"
    "qt"
    "xdg"
    "xdg-autostart"
    "xdg-desktop-entries"
    "xdg-mime"
    "xdg-mime-apps"
    "xdg-portal"
    "xdg-system-dirs"
    "xdg-terminal-exec"
    "xdg-user-dirs"
    "xfconf"
  ];

  # Discover all misc modules from HM source.
  discoverModules = dir:
    lib.pipe (builtins.readDir dir) [
      (lib.filterAttrs (name: type:
        (type == "regular" && lib.hasSuffix ".nix" name)
        || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))))
      (lib.mapAttrsToList (name: type:
        if type == "regular" then lib.removeSuffix ".nix" name else name))
    ];

  discovered = discoverModules "${hmSrc}/modules/misc";
  needsLoading = builtins.filter (m: !(builtins.elem m alreadyHandled)) discovered;

  hmModulePath = name: let
    filePath = "${hmSrc}/modules/misc/${name}.nix";
    dirPath = "${hmSrc}/modules/misc/${name}/default.nix";
  in
    if builtins.pathExists filePath then filePath
    else dirPath;
in {
  imports = map (m: wrapHmModule (hmModulePath m)) needsLoading;
}

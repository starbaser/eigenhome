{
  home-manager,
  hmExtLib,
}: let
  hmSrc = "${home-manager}";
  wrapHmModule = import ./wrap-hm-module.nix {inherit hmExtLib;};
in {
  imports = [
    (import ./lib-hm.nix {inherit home-manager hmExtLib;})
    ./home-options.nix
    ./xdg-options.nix
    ./config-lib.nix
    ./translation.nix
    ./shell-stubs.nix
    ./shell-bridge.nix
    ./activation-runner.nix
    ./systemd-bridge.nix
    ./cross-module-stubs.nix
    # HM modules explicitly listed in modules/modules.nix (not auto-discovered).
    # Matches HM's convention: accounts, config, i18n, targets, and top-level modules.
    (wrapHmModule "${hmSrc}/modules/accounts/calendar.nix")
    (wrapHmModule "${hmSrc}/modules/accounts/contacts.nix")
    (wrapHmModule "${hmSrc}/modules/accounts/email.nix")
    (wrapHmModule "${hmSrc}/modules/config/i18n.nix")
    (wrapHmModule "${hmSrc}/modules/i18n/input-method/default.nix")
    (wrapHmModule "${hmSrc}/modules/xsession.nix")
    (wrapHmModule "${hmSrc}/modules/wayland.nix")
    # Auto-discovered HM module directories.
    (import ./misc-stubs.nix {inherit hmSrc wrapHmModule;})
    (import ./programs-stubs.nix {inherit hmSrc wrapHmModule;})
    (import ./services-stubs.nix {inherit hmSrc wrapHmModule;})
    ./cursor-bridge.nix
    ./dconf-bridge.nix
    ./fontconfig-bridge.nix
    ./warnings.nix
  ];
}

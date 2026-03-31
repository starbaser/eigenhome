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
    (wrapHmModule "${hmSrc}/modules/xsession.nix")
    (wrapHmModule "${hmSrc}/modules/wayland.nix")
    (import ./programs-stubs.nix {inherit hmSrc wrapHmModule;})
    (import ./services-stubs.nix {inherit hmSrc wrapHmModule;})
    ./cursor-bridge.nix
    ./dconf-bridge.nix
    ./fontconfig-bridge.nix
    ./warnings.nix
  ];
}

{home-manager}: {
  imports = [
    (import ./lib-hm.nix {inherit home-manager;})
    ./home-options.nix
    ./xdg-options.nix
    ./config-lib.nix
    ./translation.nix
    ./shell-stubs.nix
    ./shell-bridge.nix
    ./activation-runner.nix
    ./systemd-bridge.nix
    ./cross-module-stubs.nix
    ./programs-stubs.nix
    ./cursor-bridge.nix
    ./dconf-bridge.nix
    ./fontconfig-bridge.nix
    ./warnings.nix
  ];
}

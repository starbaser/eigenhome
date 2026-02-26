{ home-manager }:
{
  imports = [
    (import ./lib-hm.nix { inherit home-manager; })
    ./home-options.nix
    ./xdg-options.nix
    ./config-lib.nix
    ./translation.nix
    ./shell-stubs.nix
    ./shell-bridge.nix
    ./cross-module-stubs.nix
    ./warnings.nix
  ];
}

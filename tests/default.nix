{
  self,
  home-manager,
  rum,
  hmExtLib,
  pkgs,
}: let
  eigenhomeTest = test:
    (pkgs.testers.runNixOSTest {
      defaults.documentation.enable = pkgs.lib.mkDefault false;
      imports = [test];
    }).config.result;

  eigenhomeModule = self.nixosModules.default;
  smfh = self.packages.${pkgs.system}.smfh;

  callTest = pkgs.newScope {
    inherit eigenhomeTest eigenhomeModule smfh;
  };
in {
  basic = callTest ./basic.nix {};
  linker = callTest ./linker.nix {};
  xdg = callTest ./xdg.nix {};
  xdg-linker = callTest ./xdg-linker.nix {};
  special-args = callTest ./special-args.nix {};
  no-users-linker = callTest ./no-users-linker.nix {};
}

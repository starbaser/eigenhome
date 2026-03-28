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
  eigenhomeHmCompat = self.homeModules.hm-compat;
  eigenhomeRum = rum.hjemModules.default;
  smfh = self.packages.${pkgs.system}.smfh;
  wrapHmModule = import ../modules/hm-compat/wrap-hm-module.nix {inherit hmExtLib;};
  hmSrc = "${home-manager}";

  callTest = pkgs.newScope {
    inherit eigenhomeTest eigenhomeModule eigenhomeHmCompat eigenhomeRum smfh wrapHmModule hmSrc;
  };
in {
  basic = callTest ./basic.nix {};
  linker = callTest ./linker.nix {};
  xdg = callTest ./xdg.nix {};
  xdg-linker = callTest ./xdg-linker.nix {};
  special-args = callTest ./special-args.nix {};
  no-users-linker = callTest ./no-users-linker.nix {};
  starship = callTest ./starship.nix {};
  git = callTest ./git.nix {};
  direnv = callTest ./direnv.nix {};
  activation = callTest ./activation.nix {};
  systemd-bridge = callTest ./systemd-bridge.nix {};
  firefox = callTest ./firefox.nix {};
  yazi = callTest ./yazi.nix {};
  starship-rum = callTest ./starship-rum.nix {};
  services-stub = callTest ./services-stub.nix {};
}

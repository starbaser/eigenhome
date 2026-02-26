{
  pkgs,
  self ? ../.,
  hjem,
  home-manager,
}:
let
  system = pkgs.system;

  hjemModule = hjem.nixosModules.default;
  hjemCompatModule = import "${self}/modules" { inherit home-manager; };
  hmSrc = "${home-manager}";

  hjemTest =
    test:
    (pkgs.testers.runNixOSTest {
      defaults.documentation.enable = pkgs.lib.mkDefault false;
      imports = [ test ];
    }).config.result;
in
{
  basic-files = pkgs.callPackage ./basic-files.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };

  starship = pkgs.callPackage ./starship.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };

  git = pkgs.callPackage ./git.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };

  direnv = pkgs.callPackage ./direnv.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };
}

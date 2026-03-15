{
  pkgs,
  self ? ../.,
  hjem,
  hjem-rum,
  home-manager,
}: let
  hjemModule = hjem.nixosModules.default;
  hjemRumModule = hjem-rum.hjemModules.default;
  hjemCompatModule = import "${self}/modules" {inherit home-manager;};
  hjemCompatNixosModule = "${self}/nixos/activation.nix";
  hmSrc = "${home-manager}";

  hmExtLib = pkgs.lib.extend (
    self: super: {
      hm = import "${home-manager}/modules/lib" {lib = self;};
    }
  );
  wrapHmModule = import "${self}/modules/wrap-hm-module.nix" {inherit hmExtLib;};

  hjemTest = test:
    (pkgs.testers.runNixOSTest {
      defaults.documentation.enable = pkgs.lib.mkDefault false;
      imports = [test];
    }).config.result;
in {
  basic-files = pkgs.callPackage ./basic-files.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };

  starship = pkgs.callPackage ./starship.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };

  starship-rum = pkgs.callPackage ./starship-rum.nix {
    inherit hjemModule hjemRumModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };

  git = pkgs.callPackage ./git.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };

  direnv = pkgs.callPackage ./direnv.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };

  activation = pkgs.callPackage ./activation.nix {
    inherit hjemModule hjemCompatModule hjemCompatNixosModule hjemTest hmSrc;
  };

  systemd-bridge = pkgs.callPackage ./systemd-bridge.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc;
  };

  firefox = pkgs.callPackage ./firefox.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };

  yazi = pkgs.callPackage ./yazi.nix {
    inherit hjemModule hjemCompatModule hjemTest hmSrc wrapHmModule;
  };
}

{
  description = "eigenhome — declarative home directory management for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    smfh = {
      url = "github:feel-co/smfh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem-rum = {
      url = "github:snugnug/hjem-rum";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    smfh,
    home-manager,
    hjem-rum,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    hmExtLib = nixpkgs.lib.extend (self: _super: {
      hm = import "${home-manager}/modules/lib" {lib = self;};
    });
    coreModules = import ./modules/nixos;
  in {
    nixosModules = {
      inherit (coreModules) eigenhome eigenhome-lib;
      activation = ./nixos/activation.nix;
      default = {
        imports = [
          coreModules.eigenhome
          ./nixos/activation.nix
        ];
      };
    };

    eigenhomeModules = {
      hm-compat = import ./modules/hm-compat {
        inherit home-manager hmExtLib;
      };
      default = self.eigenhomeModules.hm-compat;
    };

    packages = forAllSystems (system: {
      smfh = smfh.packages.${system}.smfh;
    });

    checks = forAllSystems (
      system:
        import ./tests {
          inherit self home-manager hjem-rum hmExtLib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );
  };
}

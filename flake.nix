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

    rum = {
      url = "github:snugnug/hjem-rum";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hjem.inputs.smfh.follows = "smfh";
    };
  };

  outputs = {
    self,
    nixpkgs,
    smfh,
    home-manager,
    rum,
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
      inherit (coreModules) eigenhome hjem-lib;
      activation = ./nixos/activation.nix;
      default = {
        imports = [
          coreModules.eigenhome
          ./nixos/activation.nix
          {config.eigenhome.specialArgs.hmExtLib = hmExtLib;}
        ];
      };
      hjem-compat = ./modules/nixos/hjem-compat.nix;
    };

    homeModules = {
      hm-compat = import ./modules/hm-compat {
        inherit home-manager hmExtLib;
      };
      default = self.homeModules.hm-compat;
    };

    nixOnDroidModules.default = import ./nix-on-droid {eigenhome = self;};


    packages = forAllSystems (system: {
      smfh = smfh.packages.${system}.smfh;
    });

    checks = forAllSystems (
      system:
        import ./tests {
          inherit self home-manager rum hmExtLib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );
  };
}

{smfh}: rec {
  eigenhome = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      hjem-lib
      ./base.nix
    ];

    eigenhome.linker = lib.mkDefault smfh.packages.${pkgs.stdenv.hostPlatform.system}.smfh;
  };
  hjem-lib = {
    lib,
    pkgs,
    ...
  }: {
    _module.args.hjem-lib = import ../../lib {inherit lib pkgs;};
  };
  default = eigenhome;
}

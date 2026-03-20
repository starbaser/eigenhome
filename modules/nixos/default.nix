rec {
  eigenhome = {
    imports = [
      hjem-lib
      ./base.nix
    ];
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

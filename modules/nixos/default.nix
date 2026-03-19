rec {
  eigenhome = {
    imports = [
      eigenhome-lib
      ./base.nix
    ];
  };
  eigenhome-lib = {
    lib,
    pkgs,
    ...
  }: {
    _module.args.eigenhome-lib = import ../../lib {inherit lib pkgs;};
  };
  default = eigenhome;
}

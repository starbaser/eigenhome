{ home-manager }:
# Inject lib.hm into the module system's lib argument and expose the HM source path.
# HM's lib/default.nix is pure — takes only { lib } and returns a plain attrset
# containing dag, types, shell, generators, strings, etc.
# We use the same lib.extend pattern as HM's own stdlib-extended.nix.
{ lib, ... }:
{
  _module.args = {
    lib = lib.extend (
      self: super: {
        hm = import "${home-manager}/modules/lib" { lib = self; };
      }
    );
    hmSrc = "${home-manager}";
  };
}

{ home-manager }:
# Inject lib.hm into the module system's lib argument.
#
# Challenge: _module.args.lib uses types.raw (mergeOneOption), so we can't just
# add another definition. We need mkForce to override the system default.
# Also: we must break circularity by getting base lib from pkgs (specialArgs),
# not from the module's lib argument (which comes from _module.args).
{ pkgs, ... }:
let
  baseLib = pkgs.lib;
  extendedLib = baseLib.extend (
    self: super: {
      hm = import "${home-manager}/modules/lib" { lib = self; };
    }
  );
in
{
  _module.args = {
    lib = baseLib.mkForce extendedLib;
    hmSrc = "${home-manager}";
  };
}

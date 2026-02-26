{ home-manager }:
# Inject lib.hm as a module argument (hmLib) since lib itself cannot be
# overridden from within modules (_module.args.lib is ignored when lib
# is hardwired in the base args set).
#
# For our own modules: we pass hmLib and hmExtLib through _module.args.
# For imported HM modules: they must be wrapped to receive the extended lib.
{ pkgs, ... }:
let
  baseLib = pkgs.lib;
  hmLib = import "${home-manager}/modules/lib" { lib = baseLib; };
  extendedLib = baseLib.extend (
    self: super: {
      hm = import "${home-manager}/modules/lib" { lib = self; };
    }
  );
in
{
  _module.args = {
    hmLib = hmLib;
    hmExtLib = extendedLib;
    hmSrc = "${home-manager}";
    # Wrapper for importing HM program modules: injects lib.hm
    wrapHmModule = import ./wrap-hm-module.nix { hmExtLib = extendedLib; };
  };
}

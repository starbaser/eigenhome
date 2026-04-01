{
  home-manager,
  hmExtLib,
}: {
  ...
}: {
  _module.args = {
    lib = hmExtLib;
    hmLib = hmExtLib.hm;
    inherit hmExtLib;
    hmSrc = "${home-manager}";
    wrapHmModule = import ./wrap-hm-module.nix {inherit hmExtLib;};
  };
}

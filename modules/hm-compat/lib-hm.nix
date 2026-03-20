{
  home-manager,
  hmExtLib,
}: {
  ...
}: {
  _module.args = {
    hmLib = hmExtLib.hm;
    inherit hmExtLib;
    hmSrc = "${home-manager}";
    wrapHmModule = import ./wrap-hm-module.nix {inherit hmExtLib;};
  };
}

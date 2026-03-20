# config.lib.* helpers that HM modules read.
# Declared as a freeform attrset so wrapped modules (Stylix, etc.)
# can define their own config.lib.* values for inter-module communication.
{
  hmExtLib,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.lib = mkOption {
    type = types.attrsOf types.anything;
    default = {};
    internal = true;
    description = "Library of helper functions for inter-module communication.";
  };

  config.lib = {
    file.mkOutOfStoreSymlink = path: "${path}";
    shell.exportAll = hmExtLib.hm.shell.exportAll;
    bash.initHomeManagerLib = "";
  };
}

# config.lib.* helpers that HM modules read.
{
  hmExtLib,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.lib = {
    file = {
      mkOutOfStoreSymlink = mkOption {
        type = types.functionTo types.str;
        readOnly = true;
        description = "Create a symlink target pointing to a path outside the Nix store.";
      };
    };

    shell = {
      exportAll = mkOption {
        type = types.functionTo types.str;
        readOnly = true;
        description = "Export all session variables as shell export statements.";
      };
    };

    bash = {
      initHomeManagerLib = mkOption {
        type = types.lines;
        readOnly = true;
        default = "";
        description = "Bash library initialization (stub for compatibility).";
      };
    };
  };

  config.lib = {
    file.mkOutOfStoreSymlink = path: "${path}";
    shell.exportAll = hmExtLib.hm.shell.exportAll;
  };
}

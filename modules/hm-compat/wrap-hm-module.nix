# Wraps an HM module so it receives lib with lib.hm.
# HM modules expect lib.hm.* to be available (e.g., lib.hm.shell.mkBashIntegrationOption).
# Since the module system hardwires lib and _module.args cannot override it,
# this intercepts the module function call to inject the extended lib.
#
# Multi-file HM modules (e.g., firefox) use `imports` to bring in sub-modules.
# Those sub-modules would normally receive the original lib (without lib.hm)
# from the module system. We recursively wrap imports so every layer gets
# the extended lib.
#
# Accepts paths/strings (imported first) or pre-imported modules (functions/attrsets).
# This allows wrapping both HM source paths and flake module outputs:
#   wrapHmModule "${hmSrc}/modules/programs/foo.nix"   # path
#   wrapHmModule inputs.stylix.homeModules.stylix       # flake output (function)
{hmExtLib}: let
  wrapImport = mod:
    if builtins.isPath mod || builtins.isString mod then
      wrapImport (import mod)
    else if builtins.isFunction mod then
      args: wrapImport (mod (args // {lib = hmExtLib;}))
    else if builtins.isAttrs mod && mod ? imports then
      mod // {imports = map wrapImport mod.imports;}
    else
      mod;
in
  wrapImport

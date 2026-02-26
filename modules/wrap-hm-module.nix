# Wraps an HM program module so it receives lib with lib.hm.
# HM modules expect lib.hm.* to be available (e.g., lib.hm.shell.mkBashIntegrationOption).
# Since the module system hardwires lib and _module.args cannot override it,
# we intercept the module function call to inject the extended lib.
{ hmExtLib }:
hmModulePath:
# Return a module function that wraps the original
args:
let
  # Import the HM module
  hmModule = import hmModulePath;

  # Call it with the extended lib
  result = hmModule (args // { lib = hmExtLib; });
in
result

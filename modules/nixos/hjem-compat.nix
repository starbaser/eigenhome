# Hjem namespace compatibility: aliases hjem.* options to eigenhome.*.
# Import this alongside eigenhome's nixosModules.default to allow existing
# hjem configurations to evaluate with deprecation warnings.
{lib, ...}: {
  imports = [
    (lib.mkRenamedOptionModule ["hjem" "users"] ["eigenhome" "users"])
    (lib.mkRenamedOptionModule ["hjem" "extraModules"] ["eigenhome" "extraModules"])
    (lib.mkRenamedOptionModule ["hjem" "specialArgs"] ["eigenhome" "specialArgs"])
    (lib.mkRenamedOptionModule ["hjem" "linker"] ["eigenhome" "linker"])
    (lib.mkRenamedOptionModule ["hjem" "linkerOptions"] ["eigenhome" "linkerOptions"])
    (lib.mkRenamedOptionModule ["hjem" "clobberByDefault"] ["eigenhome" "clobberByDefault"])
    (lib.mkRemovedOptionModule ["hjem" "darwinModules"] "eigenhome does not support Darwin via this path.")
  ];
}

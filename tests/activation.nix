# Test: Activation DAG runner — custom entries execute, HM built-in phases filtered.
{
  nixosModule,
  eigenhomeHmCompat,
  eigenhomeTest,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-activation";
    nodes.machine = {
      imports = [nixosModule];

      users.groups.alice = {};
      users.users.alice = {
        isNormalUser = true;
        home = userHome;
        password = "";
      };

      eigenhome.linker = null;
      eigenhome.users.alice = {
        enable = true;
        imports = [eigenhomeHmCompat];

        # Custom activation entry — should appear in script.
        home.activation.createTestDir = ''
          mkdir -p "$HOME/.local/share/test-activation"
          echo "activated" > "$HOME/.local/share/test-activation/marker"
        '';

        # HM built-in phase — should be filtered out.
        home.activation.writeBoundary = ''
          echo "hjem-compat boundary marker"
        '';
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -L ${userHome}/.local/share/eigenhome/activate")

      machine.succeed("test -L ${userHome}/.local/share/eigenhome/activate")

      machine.succeed("grep 'createTestDir' ${userHome}/.local/share/eigenhome/activate")
      machine.fail("grep 'writeBoundary' ${userHome}/.local/share/eigenhome/activate")

      machine.succeed("su alice --login --command '${userHome}/.local/share/eigenhome/activate'")

      machine.succeed("test -f ${userHome}/.local/share/test-activation/marker")
      machine.succeed("grep 'activated' ${userHome}/.local/share/test-activation/marker")
    '';
  }

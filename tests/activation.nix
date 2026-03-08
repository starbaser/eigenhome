# Test: Activation DAG runner — custom entries execute, HM built-in phases filtered.
{
  hjemModule,
  hjemCompatModule,
  hjemCompatNixosModule,
  hjemTest,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-activation";
    nodes.machine = {
      imports = [
        hjemModule
        hjemCompatNixosModule
      ];

      users.groups.alice = {};
      users.users.alice = {
        isNormalUser = true;
        home = userHome;
        password = "";
      };

      hjem.linker = null;
      hjem.users.alice = {
        enable = true;
        imports = [hjemCompatModule];

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
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

      machine.succeed("test -L ${userHome}/.local/share/hjem-compat/activate")

      machine.succeed("grep 'createTestDir' ${userHome}/.local/share/hjem-compat/activate")
      machine.fail("grep 'writeBoundary' ${userHome}/.local/share/hjem-compat/activate")

      machine.succeed("su alice --login --command '${userHome}/.local/share/hjem-compat/activate'")

      machine.succeed("test -f ${userHome}/.local/share/test-activation/marker")
      machine.succeed("grep 'activated' ${userHome}/.local/share/test-activation/marker")
    '';
  }

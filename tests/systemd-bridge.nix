# Test: systemd.user bridge generates correct INI unit files via hjem.
{
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-systemd-bridge";
    nodes.machine = {
      imports = [hjemModule];

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

        # Define a service through HM's INI-section interface.
        systemd.user.services.test-oneshot = {
          Unit = {
            Description = "hjem-compat test oneshot service";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "/run/current-system/sw/bin/echo hello-from-test";
          };
        };

        # Define a timer to verify non-service unit types.
        systemd.user.timers.test-timer = {
          Unit = {
            Description = "hjem-compat test timer";
          };
          Timer = {
            OnCalendar = "daily";
            Persistent = true;
          };
          Install = {
            WantedBy = ["timers.target"];
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

      machine.succeed("test -e ${userHome}/.config/systemd/user/test-oneshot.service")
      machine.succeed("grep 'hjem-compat test oneshot service' ${userHome}/.config/systemd/user/test-oneshot.service")
      machine.succeed("grep 'Type=oneshot' ${userHome}/.config/systemd/user/test-oneshot.service")
      machine.succeed("grep 'ExecStart' ${userHome}/.config/systemd/user/test-oneshot.service")

      machine.succeed("test -e ${userHome}/.config/systemd/user/test-timer.timer")
      machine.succeed("grep 'hjem-compat test timer' ${userHome}/.config/systemd/user/test-timer.timer")
      machine.succeed("grep 'OnCalendar=daily' ${userHome}/.config/systemd/user/test-timer.timer")
      machine.succeed("grep 'Persistent=true' ${userHome}/.config/systemd/user/test-timer.timer")

      machine.succeed("test -L ${userHome}/.config/systemd/user/timers.target.wants/test-timer.timer")

      machine.succeed("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user cat test-oneshot.service")
    '';
  }

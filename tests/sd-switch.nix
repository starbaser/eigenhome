# Test: sd-switch manages user service lifecycle during eigenhome activation.
# Verifies services start on first activation, restart when config changes,
# and stop when removed — using specialisation-based config switching.
{
  nixosModule,
  eigenhomeHmCompat,
  eigenhomeTest,
  smfh,
  pkgs,
}: let
  user = "alice";
  userHome = "/home/${user}";
in
  eigenhomeTest {
    name = "eigenhome-sd-switch";
    nodes.node1 = {
      imports = [nixosModule];

      nix.enable = false;

      users.groups.${user} = {};
      users.users.${user} = {
        isNormalUser = true;
        home = userHome;
        password = "";
      };

      eigenhome = {
        linker = smfh;
        users.${user} = {
          enable = true;
          imports = [eigenhomeHmCompat];

          systemd.user.services.test-daemon = {
            Unit.Description = "sd-switch test daemon";
            Service = {
              Type = "simple";
              ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
            };
            Install.WantedBy = ["default.target"];
          };
        };
      };

      specialisation = {
        changedService.configuration = {
          eigenhome.users.${user}.systemd.user.services.test-daemon = pkgs.lib.mkForce {
            Unit.Description = "sd-switch test daemon (changed)";
            Service = {
              Type = "simple";
              ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
              Environment = "CHANGED=1";
            };
            Install.WantedBy = ["default.target"];
          };
        };

        removedService.configuration = {
          eigenhome.users.${user}.systemd.user.services = pkgs.lib.mkForce {};
        };
      };
    };

    testScript = {nodes, ...}: let
      baseSystem = nodes.node1.system.build.toplevel;
      specialisations = "${baseSystem}/specialisation";
    in ''
      node1.succeed("loginctl enable-linger ${user}")
      node1.wait_for_unit("user@1000.service")

      with subtest("First activation starts service via sd-switch"):
          node1.succeed("${baseSystem}/bin/switch-to-configuration test")
          node1.wait_until_succeeds(
              "sudo -u ${user} XDG_RUNTIME_DIR=/run/user/1000 "
              "systemctl --user is-active test-daemon.service"
          )
          pid1 = node1.succeed(
              "sudo -u ${user} XDG_RUNTIME_DIR=/run/user/1000 "
              "systemctl --user show test-daemon.service -p MainPID --value"
          ).strip()
          assert pid1 != "" and pid1 != "0", f"Invalid PID after first activation: {pid1}"

      with subtest("Changed service gets restarted"):
          node1.succeed("${specialisations}/changedService/bin/switch-to-configuration test")
          node1.wait_until_succeeds(
              "sudo -u ${user} XDG_RUNTIME_DIR=/run/user/1000 "
              "systemctl --user is-active test-daemon.service"
          )
          pid2 = node1.succeed(
              "sudo -u ${user} XDG_RUNTIME_DIR=/run/user/1000 "
              "systemctl --user show test-daemon.service -p MainPID --value"
          ).strip()
          assert pid1 != pid2, f"Service was not restarted: PID stayed {pid1}"

      with subtest("Removed service gets stopped"):
          node1.succeed("${specialisations}/removedService/bin/switch-to-configuration test")
          node1.wait_until_fails(
              "sudo -u ${user} XDG_RUNTIME_DIR=/run/user/1000 "
              "systemctl --user is-active test-daemon.service"
          )
    '';
  }

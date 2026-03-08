# Test: HM home.file and xdg.configFile entries translate to hjem files.
{
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  writeText,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-basic-files";
    nodes = {
      machine = {
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

          # Write files through HM's API
          home.file.".config/test-text" = {
            text = "hello from hjem-compat";
          };

          home.file.".local/bin/test-script" = {
            text = ''
              #!/bin/sh
              echo "it works"
            '';
            executable = true;
          };

          # XDG file via HM API
          xdg.configFile."compat-test/config.txt" = {
            text = "xdg config file test";
          };

          xdg.dataFile."compat-test/data.txt" = {
            text = "xdg data file test";
          };

          # HM packages
          home.packages = [];

          # Session variables via HM API
          home.sessionVariables = {
            COMPAT_TEST = "active";
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

      machine.succeed("test -L ${userHome}/.config/test-text")
      machine.succeed("grep 'hello from hjem-compat' ${userHome}/.config/test-text")

      machine.succeed("test -L ${userHome}/.local/bin/test-script")

      machine.succeed("test -L ${userHome}/.config/compat-test/config.txt")
      machine.succeed("grep 'xdg config file test' ${userHome}/.config/compat-test/config.txt")

      machine.succeed("test -L ${userHome}/.local/share/compat-test/data.txt")
      machine.succeed("grep 'xdg data file test' ${userHome}/.local/share/compat-test/data.txt")
    '';
  }

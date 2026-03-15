# Test: HM yazi module — fish shell wrapper function
{
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  wrapHmModule,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-yazi";
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
        imports = [
          hjemCompatModule
          (wrapHmModule "${hmSrc}/modules/programs/yazi.nix")
        ];

        programs.yazi = {
          enable = true;
          shellWrapperName = "y";
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

      # Fish function file deployed
      machine.succeed("test -e ${userHome}/.config/fish/functions/y.fish")
      machine.succeed("grep 'function y' ${userHome}/.config/fish/functions/y.fish")
      machine.succeed("grep 'yazi' ${userHome}/.config/fish/functions/y.fish")
    '';
  }

# Test: HM git module
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
    name = "hjem-compat-git";
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
          (wrapHmModule "${hmSrc}/modules/programs/git.nix")
        ];

        programs.git = {
          enable = true;
          userName = "Alice Test";
          userEmail = "alice@example.com";
          ignores = ["*.swp" ".direnv"];
          aliases = {
            co = "checkout";
            st = "status";
          };
          extraConfig = {
            core.editor = "vim";
            pull.rebase = true;
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

      machine.succeed("su alice --login --command 'which git'")

      machine.succeed("test -e ${userHome}/.config/git/config")
      machine.succeed("grep 'Alice Test' ${userHome}/.config/git/config")
      machine.succeed("grep 'alice@example.com' ${userHome}/.config/git/config")

      machine.succeed("test -e ${userHome}/.config/git/ignore")
      machine.succeed("grep '.swp' ${userHome}/.config/git/ignore")
    '';
  }

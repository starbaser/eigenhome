# Test: HM git module
{
  eigenhomeModule,
  eigenhomeHmCompat,
  eigenhomeTest,
  wrapHmModule,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-git";
    nodes.machine = {
      imports = [eigenhomeModule];

      users.groups.alice = {};
      users.users.alice = {
        isNormalUser = true;
        home = userHome;
        password = "";
      };

      eigenhome.linker = null;
      eigenhome.users.alice = {
        enable = true;
        imports = [
          eigenhomeHmCompat
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
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.config/git/config")

      machine.succeed("su alice --login --command 'which git'")

      machine.succeed("test -e ${userHome}/.config/git/config")
      machine.succeed("grep 'Alice Test' ${userHome}/.config/git/config")
      machine.succeed("grep 'alice@example.com' ${userHome}/.config/git/config")

      machine.succeed("test -e ${userHome}/.config/git/ignore")
      machine.succeed("grep '.swp' ${userHome}/.config/git/ignore")
    '';
  }

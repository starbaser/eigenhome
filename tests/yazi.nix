# Test: HM yazi module — fish shell wrapper function
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
    name = "eigenhome-yazi";
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
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.config/fish/functions/y.fish")

      # Fish function file deployed
      machine.succeed("test -e ${userHome}/.config/fish/functions/y.fish")
      machine.succeed("grep 'function y' ${userHome}/.config/fish/functions/y.fish")
      machine.succeed("grep 'yazi' ${userHome}/.config/fish/functions/y.fish")
    '';
  }

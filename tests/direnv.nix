# Test: HM direnv module
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
    name = "eigenhome-direnv";
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
          (wrapHmModule "${hmSrc}/modules/programs/direnv.nix")
        ];

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
          config.global.warn_timeout = "10s";
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.config/direnv/direnv.toml")

      machine.succeed("su alice --login --command 'which direnv'")

      machine.succeed("test -e ${userHome}/.config/direnv/direnv.toml")
      machine.succeed("grep 'warn_timeout' ${userHome}/.config/direnv/direnv.toml")

      machine.succeed("test -e ${userHome}/.config/direnv/lib/hm-nix-direnv.sh")

      machine.succeed("test -e ${userHome}/.config/zsh/hm-compat.zsh")
      machine.succeed("grep 'direnv' ${userHome}/.config/zsh/hm-compat.zsh")

      machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
      machine.succeed("grep 'direnv' ${userHome}/.config/bash/hm-compat.sh")
    '';
  }

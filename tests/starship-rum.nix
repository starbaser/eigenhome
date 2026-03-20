# Test: HM starship module with rum zsh active.
{
  eigenhomeModule,
  eigenhomeRum,
  eigenhomeHmCompat,
  eigenhomeTest,
  wrapHmModule,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-starship-rum";
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
          eigenhomeRum
          eigenhomeHmCompat
          (wrapHmModule "${hmSrc}/modules/programs/starship.nix")
        ];

        # Enable rum's zsh module
        rum.programs.zsh.enable = true;

        programs.starship = {
          enable = true;
          settings.add_newline = false;
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.config/starship.toml")

      machine.succeed("su alice --login --command 'which starship'")

      machine.succeed("test -e ${userHome}/.config/starship.toml")

      # rum zsh routes init to .zshrc, not standalone file
      machine.succeed("grep 'starship init zsh' ${userHome}/.zshrc")
      machine.fail("test -e ${userHome}/.config/zsh/hm-compat.zsh")

      # bash/fish still standalone (no rum)
      machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
      machine.succeed("test -e ${userHome}/.config/fish/conf.d/hm-compat.fish")
    '';
  }

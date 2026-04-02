# Test: HM starship module (standalone, no rum)
{
  nixosModule,
  eigenhomeHmCompat,
  eigenhomeTest,
  wrapHmModule,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-starship";
    nodes.machine = {
      imports = [nixosModule];

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
        ];

        programs.starship = {
          enable = true;
          settings = {
            add_newline = false;
            character.success_symbol = "[>](bold green)";
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.config/starship.toml")

      machine.succeed("su alice --login --command 'which starship'")

      machine.succeed("test -e ${userHome}/.config/starship.toml")
      machine.succeed("grep 'add_newline' ${userHome}/.config/starship.toml")

      # Shell init (standalone fallback — no rum)
      machine.succeed("test -e ${userHome}/.config/zsh/hm-compat.zsh")
      machine.succeed("grep 'starship init zsh' ${userHome}/.config/zsh/hm-compat.zsh")

      machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
      machine.succeed("grep 'starship init bash' ${userHome}/.config/bash/hm-compat.sh")

      machine.succeed("test -e ${userHome}/.config/fish/conf.d/hm-compat.fish")
      machine.succeed("grep 'starship init fish' ${userHome}/.config/fish/conf.d/hm-compat.fish")
    '';
  }

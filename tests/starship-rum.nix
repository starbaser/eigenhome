# Test: HM starship module with rum zsh active.
{
  hjemModule,
  hjemRumModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  wrapHmModule,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-starship-rum";
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
          hjemRumModule
          hjemCompatModule
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
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

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

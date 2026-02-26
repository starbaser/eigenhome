# Test: HM starship module (standalone, no rum)
{
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  wrapHmModule,
}:
let
  userHome = "/home/alice";
in
hjemTest {
  name = "hjem-compat-starship";
  nodes.machine = {
    imports = [ hjemModule ];

    users.groups.alice = { };
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
        (wrapHmModule "${hmSrc}/modules/programs/starship.nix")
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
    machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
    machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

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

# Test: HM direnv module
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
  name = "hjem-compat-direnv";
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
    machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
    machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

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

# Test: HM starship module with rum zsh active.
# Verifies: starship shell init routes through rum.programs.zsh.initConfig
# instead of standalone files.
{
  hjemModule,
  hjemRumModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  wrapHmModule,
}:
let
  userHome = "/home/alice";
in
hjemTest {
  name = "hjem-compat-starship-rum";
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
    machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

    machine.succeed("su alice --login --command 'which starship'")

    # Starship config file should exist
    machine.succeed("test -e ${userHome}/.config/starship.toml")

    # With rum zsh active, starship init should be in .zshrc (via rum),
    # NOT in the standalone hm-compat.zsh file
    machine.succeed("grep 'starship init zsh' ${userHome}/.zshrc")
    machine.fail("test -e ${userHome}/.config/zsh/hm-compat.zsh")

    # Bash/fish should still use standalone (no rum modules for those)
    machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
    machine.succeed("test -e ${userHome}/.config/fish/conf.d/hm-compat.fish")
  '';
}

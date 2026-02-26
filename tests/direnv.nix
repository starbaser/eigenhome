# Test: Import HM's direnv module via wrapHmModule.
{
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  lib,
  pkgs,
}:
let
  userHome = "/home/alice";

  hmExtLib = pkgs.lib.extend (
    self: super: {
      hm = import "${hmSrc}/modules/lib" { lib = self; };
    }
  );
  wrapHmModule = import ../modules/wrap-hm-module.nix { inherit hmExtLib; };
in
hjemTest {
  name = "hjem-compat-direnv";
  nodes = {
    machine = {
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
          config = {
            global.warn_timeout = "10s";
          };
        };
      };
    };
  };

  testScript = ''
    machine.succeed("loginctl enable-linger alice")
    machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

    # Verify direnv package is available
    machine.succeed("su alice --login --command 'which direnv'")

    # Verify direnv.toml config
    machine.succeed("test -e ${userHome}/.config/direnv/direnv.toml")
    machine.succeed("grep 'warn_timeout' ${userHome}/.config/direnv/direnv.toml")

    # Verify nix-direnv integration
    machine.succeed("test -e ${userHome}/.config/direnv/lib/hm-nix-direnv.sh")

    # Verify shell hooks were generated (standalone fallback, no rum)
    machine.succeed("test -e ${userHome}/.config/zsh/hm-compat.zsh")
    machine.succeed("grep 'direnv' ${userHome}/.config/zsh/hm-compat.zsh")

    machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
    machine.succeed("grep 'direnv' ${userHome}/.config/bash/hm-compat.sh")

    machine.succeed("test -e ${userHome}/.config/fish/conf.d/hm-compat.fish")
    machine.succeed("grep 'direnv' ${userHome}/.config/fish/conf.d/hm-compat.fish")
  '';
}

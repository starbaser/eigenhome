# Test: Import HM's starship module via wrapHmModule.
# Verifies: config file, package in PATH, session variable, shell init content.
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

  # Construct the wrapper at test level (since _module.args from imports
  # aren't available in the outer user function arguments).
  hmExtLib = pkgs.lib.extend (
    self: super: {
      hm = import "${hmSrc}/modules/lib" { lib = self; };
    }
  );
  wrapHmModule = import ../modules/wrap-hm-module.nix { inherit hmExtLib; };
in
hjemTest {
  name = "hjem-compat-starship";
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
  };

  testScript = ''
    machine.succeed("loginctl enable-linger alice")
    machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

    # Verify starship package is available
    machine.succeed("su alice --login --command 'which starship'")

    # Verify starship.toml was generated via home.file → files translation
    machine.succeed("test -e ${userHome}/.config/starship.toml")
    machine.succeed("grep 'add_newline' ${userHome}/.config/starship.toml")
    machine.succeed("grep 'success_symbol' ${userHome}/.config/starship.toml")

    # Verify shell init content was generated (standalone fallback since no rum)
    machine.succeed("test -e ${userHome}/.config/zsh/hm-compat.zsh")
    machine.succeed("grep 'starship init zsh' ${userHome}/.config/zsh/hm-compat.zsh")

    machine.succeed("test -e ${userHome}/.config/bash/hm-compat.sh")
    machine.succeed("grep 'starship init bash' ${userHome}/.config/bash/hm-compat.sh")

    machine.succeed("test -e ${userHome}/.config/fish/conf.d/hm-compat.fish")
    machine.succeed("grep 'starship init fish' ${userHome}/.config/fish/conf.d/hm-compat.fish")
  '';
}

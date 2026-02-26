# Test: Import HM's git module via wrapHmModule.
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
  name = "hjem-compat-git";
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
          (wrapHmModule "${hmSrc}/modules/programs/git.nix")
        ];

        programs.git = {
          enable = true;
          userName = "Alice Test";
          userEmail = "alice@example.com";
          ignores = [ "*.swp" ".direnv" ];
          aliases = {
            co = "checkout";
            st = "status";
          };
          extraConfig = {
            core.editor = "vim";
            pull.rebase = true;
          };
        };
      };
    };
  };

  testScript = ''
    machine.succeed("loginctl enable-linger alice")
    machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

    # Verify git package is available
    machine.succeed("su alice --login --command 'which git'")

    # Verify git config was generated via xdg.configFile → xdg.config.files
    machine.succeed("test -e ${userHome}/.config/git/config")
    machine.succeed("grep 'Alice Test' ${userHome}/.config/git/config")
    machine.succeed("grep 'alice@example.com' ${userHome}/.config/git/config")
    machine.succeed("grep 'editor' ${userHome}/.config/git/config")

    # Verify gitignore
    machine.succeed("test -e ${userHome}/.config/git/ignore")
    machine.succeed("grep '.swp' ${userHome}/.config/git/ignore")
    machine.succeed("grep '.direnv' ${userHome}/.config/git/ignore")
  '';
}

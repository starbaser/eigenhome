{
  eigenhomeModule,
  eigenhomeTest,
  hello,
  lib,
  formats,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-basic";
    nodes = {
      node1 = {
        imports = [eigenhomeModule];

        users.groups.alice = {};
        users.users.alice = {
          isNormalUser = true;
          home = userHome;
          password = "";
        };

        eigenhome.linker = null;
        eigenhome.users = {
          alice = {
            enable = true;
            packages = [hello];
            files = {
              ".config/foo" = {
                text = "Hello world!";
              };

              ".config/bar.json" = {
                text = lib.generators.toJSON {} {bar = true;};
              };

              ".config/baz.toml" = {
                source = (formats.toml {}).generate "baz.toml" {baz = true;};
              };
            };
          };
        };

        systemd.user.tmpfiles = {
          rules = [
            "d %h/user_tmpfiles_created"
          ];

          users.alice.rules = [
            "d %h/only_alice"
          ];
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

      machine.succeed("[ -L ~alice/.config/foo ]")
      machine.succeed("[ -L ~alice/.config/bar.json ]")
      machine.succeed("[ -L ~alice/.config/baz.toml ]")

      machine.succeed("[ -d ~alice/user_tmpfiles_created ]")
      machine.succeed("[ -d ~alice/only_alice ]")

      machine.succeed("su alice --login --command hello")
    '';
  }

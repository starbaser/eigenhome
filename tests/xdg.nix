{
  eigenhomeModule,
  eigenhomeTest,
  lib,
  formats,
  writeText,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-xdg";
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
            files = {
              "foo" = {
                text = "Hello world!";
              };
            };
            xdg = {
              cache = {
                directory = userHome + "/customCacheDirectory";
                files = {
                  "foo" = {
                    text = "Hello world!";
                  };
                };
              };
              config = {
                directory = userHome + "/customConfigDirectory";
                files = {
                  "bar.json" = {
                    text = lib.generators.toJSON {} {bar = "Hello second world!";};
                  };
                };
              };
              data = {
                directory = userHome + "/customDataDirectory";
                files = {
                  "baz.toml" = {
                    source = (formats.toml {}).generate "baz.toml" {baz = "Hello third world!";};
                  };
                };
              };
              state = {
                directory = userHome + "/customStateDirectory";
                files = {
                  "foo" = {
                    source = writeText "file-bar" "Hello fourth world!";
                  };
                };
              };

              mime-apps = {
                added-associations."text/html" = ["firefox.desktop" "zen.desktop"];
                removed-associations."text/xml" = ["thunderbird.desktop"];
                default-applications."text/html" = "firefox.desktop";
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
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -L ~alice/customCacheDirectory/foo")

      with subtest("XDG basedir spec files created"):
        machine.succeed("[ -L ~alice/customCacheDirectory/foo ]")
        machine.succeed("grep \"Hello world!\" ~alice/customCacheDirectory/foo")
        machine.succeed("[ -L ~alice/customConfigDirectory/bar.json ]")
        machine.succeed("grep \"Hello second world!\" ~alice/customConfigDirectory/bar.json")
        machine.succeed("[ -L ~alice/customDataDirectory/baz.toml ]")
        machine.succeed("grep \"Hello third world!\" ~alice/customDataDirectory/baz.toml")
        machine.succeed("[ -L ~alice/customStateDirectory/foo ]")
        machine.succeed("grep \"Hello fourth world!\" ~alice/customStateDirectory/foo")

      with subtest("XDG mime-apps spec file created"):
        machine.succeed("[ -L ~alice/customConfigDirectory/mimeapps.list ]")
        machine.succeed("grep \"text/xml\" ~alice/customConfigDirectory/mimeapps.list")

      with subtest("Basic test file"):
        machine.succeed("[ -L ~alice/foo ]")
        machine.succeed("grep \"Hello world!\" ~alice/foo")
        machine.succeed("[ -d ~alice/user_tmpfiles_created ]")
        machine.succeed("[ -d ~alice/only_alice ]")
    '';
  }

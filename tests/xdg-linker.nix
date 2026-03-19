{
  eigenhomeModule,
  eigenhomeTest,
  lib,
  formats,
  smfh,
  writeText,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-xdg-linker";
    nodes = {
      node1 = let
        inherit (lib.modules) mkIf;
        inherit (lib.strings) optionalString;

        xdg = {
          clobber,
          altLocation,
        }: {
          cache = {
            directory = mkIf altLocation (userHome + "/customCacheDirectory");
            files = {
              "foo" = {
                text = "Hello ${optionalString clobber "new "}world!";
                inherit clobber;
              };
            };
          };
          config = {
            directory = mkIf altLocation (userHome + "/customConfigDirectory");
            files = {
              "bar.json" = {
                text = lib.generators.toJSON {} {bar = "Hello ${optionalString clobber "new "}second world!";};
                inherit clobber;
              };
            };
          };
          data = {
            directory = mkIf altLocation (userHome + "/customDataDirectory");
            files = {
              "baz.toml" = {
                source = (formats.toml {}).generate "baz.toml" {baz = "Hello ${optionalString clobber "new "}third world!";};
                inherit clobber;
              };
            };
          };
          state = {
            directory = mkIf altLocation (userHome + "/customStateDirectory");
            files = {
              "foo" = {
                source = writeText "file-bar" "Hello ${optionalString clobber "new "}fourth world!";
                inherit clobber;
              };
            };
          };
        };
      in {
        imports = [eigenhomeModule];

        nix.enable = false;

        users.groups.alice = {};
        users.users.alice = {
          isNormalUser = true;
          home = userHome;
          password = "";
        };

        eigenhome = {
          linker = smfh;
          users = {
            alice = {
              enable = true;
            };
          };
        };

        specialisation = {
          defaultFilesGetLinked.configuration = {
            eigenhome.users.alice = {
              xdg = xdg {
                clobber = false;
                altLocation = false;
              };
            };
          };
          altFilesGetLinked.configuration = {
            eigenhome.users.alice = {
              files.".config/foo".text = "Hello world!";
              xdg = xdg {
                clobber = false;
                altLocation = true;
              };
            };
          };
          altFilesGetOverwritten.configuration = {
            eigenhome.users.alice = {
              files.".config/foo" = {
                text = "Hello new world!";
                clobber = true;
              };
              xdg = xdg {
                clobber = true;
                altLocation = true;
              };
            };
          };
        };
      };
    };

    testScript = {nodes, ...}: let
      baseSystem = nodes.node1.system.build.toplevel;
      specialisations = "${baseSystem}/specialisation";
    in ''
      node1.succeed("loginctl enable-linger alice")

      with subtest("Default file locations get linked"):
        node1.succeed("${specialisations}/defaultFilesGetLinked/bin/switch-to-configuration test")
        node1.succeed("test -L ${userHome}/.cache/foo")
        node1.succeed("grep \"Hello world!\" ~alice/.cache/foo")
        node1.succeed("test -L ${userHome}/.config/bar.json")
        node1.succeed("grep \"Hello second world!\" ~alice/.config/bar.json")
        node1.succeed("test -L ${userHome}/.local/share/baz.toml")
        node1.succeed("grep \"Hello third world!\" ~alice/.local/share/baz.toml")
        node1.succeed("test -L ${userHome}/.local/state/foo")
        node1.succeed("grep \"Hello fourth world!\" ~alice/.local/state/foo")

      with subtest("Alternate file locations get linked"):
        node1.succeed("${specialisations}/altFilesGetLinked/bin/switch-to-configuration test")
        node1.succeed("test -L ${userHome}/customCacheDirectory/foo")
        node1.succeed("grep \"Hello world!\" ~alice/customCacheDirectory/foo")
        node1.succeed("test -L ${userHome}/customConfigDirectory/bar.json")
        node1.succeed("grep \"Hello second world!\" ~alice/customConfigDirectory/bar.json")
        node1.succeed("test -L ${userHome}/customDataDirectory/baz.toml")
        node1.succeed("grep \"Hello third world!\" ~alice/customDataDirectory/baz.toml")
        node1.succeed("test -L ${userHome}/customStateDirectory/foo")
        node1.succeed("grep \"Hello fourth world!\" ~alice/customStateDirectory/foo")
        node1.succeed("test -L ${userHome}/.config/foo")
        node1.succeed("grep \"Hello world!\" ~alice/.config/foo")

      with subtest("Alternate file locations get overwritten when changed"):
        node1.succeed("${specialisations}/altFilesGetLinked/bin/switch-to-configuration test")
        node1.succeed("${specialisations}/altFilesGetOverwritten/bin/switch-to-configuration test")
        node1.succeed("test -L ${userHome}/customCacheDirectory/foo")
        node1.succeed("grep \"Hello new world!\" ~alice/customCacheDirectory/foo")
        node1.succeed("test -L ${userHome}/customConfigDirectory/bar.json")
        node1.succeed("grep \"Hello new second world!\" ~alice/customConfigDirectory/bar.json")
        node1.succeed("test -L ${userHome}/customDataDirectory/baz.toml")
        node1.succeed("grep \"Hello new third world!\" ~alice/customDataDirectory/baz.toml")
        node1.succeed("test -L ${userHome}/customStateDirectory/foo")
        node1.succeed("grep \"Hello new fourth world!\" ~alice/customStateDirectory/foo")
        node1.succeed("test -L ${userHome}/.config/foo")
        node1.succeed("grep \"Hello new world!\" ~alice/.config/foo")
    '';
  }

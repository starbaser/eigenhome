{
  eigenhomeModule,
  eigenhomeTest,
  hello,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-special-args";
    nodes = {
      node1 = {
        imports = [eigenhomeModule];

        users.groups.alice = {};
        users.users.alice = {
          isNormalUser = true;
          home = userHome;
          password = "";
        };

        eigenhome = {
          linker = null;
          specialArgs = {username = "alice";};
          users.alice = {username, ...}: {
            enable = true;
            packages = [hello];
            files.".config/fooconfig" = {
              text = "My username is ${username}";
            };
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -L ~alice/.config/fooconfig")

      machine.succeed("grep alice ~alice/.config/fooconfig")
    '';
  }

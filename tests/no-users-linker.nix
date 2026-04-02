{
  nixosModule,
  eigenhomeTest,
  smfh,
}: let
  user = "alice";
  userHome = "/home/${user}";
in
  eigenhomeTest {
    name = "eigenhome-no-users-linker";
    nodes = {
      node1 = {
        imports = [nixosModule];

        nix.enable = false;

        users.groups.${user} = {};
        users.users.${user} = {
          isNormalUser = true;
          home = userHome;
          password = "";
        };

        eigenhome = {
          linker = smfh;
          users = {
            ${user} = {
              enable = false;
              files.".config/foo".text = "Hello world!";
            };
          };
        };
      };
    };

    testScript = _: ''
      node1.succeed("loginctl enable-linger ${user}")
    '';
  }

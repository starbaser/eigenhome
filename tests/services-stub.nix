# Test: services-stubs evaluation — confirms HM service modules load cleanly.
{
  eigenhomeModule,
  eigenhomeHmCompat,
  eigenhomeTest,
}:
  eigenhomeTest {
    name = "eigenhome-services-stub";
    nodes.machine = {
      imports = [eigenhomeModule];

      users.groups.alice = {};
      users.users.alice = {
        isNormalUser = true;
        home = "/home/alice";
        password = "";
      };

      eigenhome.linker = null;
      eigenhome.users.alice = {
        enable = true;
        imports = [eigenhomeHmCompat];

        services.dunst.enable = false;
        services.syncthing.enable = false;
      };
    };

    testScript = ''
      machine.succeed("true")
    '';
  }

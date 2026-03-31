# Test: window-manager HM modules load with typed options via xsession.nix and wayland.nix.
# Verifies that Wayland WMs (hyprland, sway) and X11 WMs (i3) coexist without
# option merge conflicts after replacing freeform stubs with typed module imports.
{
  eigenhomeModule,
  eigenhomeHmCompat,
  eigenhomeTest,
}:
  eigenhomeTest {
    name = "eigenhome-window-managers";
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

        # Wayland WMs — typed options must resolve without merge conflicts.
        wayland.windowManager.hyprland.enable = false;
        wayland.windowManager.sway.enable = false;

        # X11 WM — typed options from xsession.nix must be accessible.
        xsession.windowManager.i3.enable = false;
      };
    };

    testScript = ''
      machine.succeed("true")
    '';
  }

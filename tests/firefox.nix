# Test: HM Firefox module — profiles.ini, user.js, userChrome/userContent.css
{
  pkgs,
  eigenhomeModule,
  eigenhomeHmCompat,
  eigenhomeTest,
  wrapHmModule,
  hmSrc,
}: let
  userHome = "/home/alice";
in
  eigenhomeTest {
    name = "eigenhome-firefox";
    nodes.machine = {
      imports = [eigenhomeModule];

      users.groups.alice = {};
      users.users.alice = {
        isNormalUser = true;
        home = userHome;
        password = "";
      };

      eigenhome.linker = null;
      eigenhome.users.alice = {
        enable = true;
        imports = [
          eigenhomeHmCompat
          (wrapHmModule "${hmSrc}/modules/programs/firefox/default.nix")
        ];

        programs.firefox = {
          enable = true;
          profiles.test-profile = {
            isDefault = true;
            settings = {
              "content.notify.interval" = 100000;
              "browser.cache.disk.enable" = false;
            };
            userChrome = "/* hjem-compat-test userChrome */";
            userContent = "/* hjem-compat-test userContent */";
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_for_unit("user@1000.service")
      machine.wait_until_succeeds("test -e ${userHome}/.mozilla/firefox/profiles.ini")

      # profiles.ini
      machine.succeed("test -e ${userHome}/.mozilla/firefox/profiles.ini")
      machine.succeed("grep 'Profile0' ${userHome}/.mozilla/firefox/profiles.ini")
      machine.succeed("grep 'test-profile' ${userHome}/.mozilla/firefox/profiles.ini")

      # user.js with settings
      machine.succeed("test -e ${userHome}/.mozilla/firefox/test-profile/user.js")
      machine.succeed("grep 'content.notify.interval' ${userHome}/.mozilla/firefox/test-profile/user.js")
      machine.succeed("grep '100000' ${userHome}/.mozilla/firefox/test-profile/user.js")

      # userChrome.css
      machine.succeed("test -e ${userHome}/.mozilla/firefox/test-profile/chrome/userChrome.css")
      machine.succeed("grep 'hjem-compat-test userChrome' ${userHome}/.mozilla/firefox/test-profile/chrome/userChrome.css")

      # userContent.css
      machine.succeed("test -e ${userHome}/.mozilla/firefox/test-profile/chrome/userContent.css")
      machine.succeed("grep 'hjem-compat-test userContent' ${userHome}/.mozilla/firefox/test-profile/chrome/userContent.css")
    '';
  }

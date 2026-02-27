# Test: HM Firefox module — profile config files via wrapHmModule
#
# Validates that programs.firefox produces correct hjem files for:
# profiles.ini, user.js (settings), userChrome.css, userContent.css
{
  pkgs,
  hjemModule,
  hjemCompatModule,
  hjemTest,
  hmSrc,
  wrapHmModule,
}: let
  userHome = "/home/alice";
in
  hjemTest {
    name = "hjem-compat-firefox";
    nodes.machine = {
      imports = [hjemModule];

      users.groups.alice = {};
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
          (wrapHmModule "${hmSrc}/modules/programs/firefox/default.nix")
          (wrapHmModule "${hmSrc}/modules/misc/mozilla-messaging-hosts.nix")
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
      machine.wait_until_succeeds("test -d /run/user/$(id -u alice)")
      machine.wait_until_succeeds("sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user is-active systemd-tmpfiles-setup.service")

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

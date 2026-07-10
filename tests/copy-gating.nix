{
  nixosModule,
  eigenhomeTest,
}: let
  user = "alice";
  userHome = "/home/${user}";
  manifest = "/var/lib/eigenhome/manifest-${user}.json";
in
  eigenhomeTest {
    name = "eigenhome-copy-gating";
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
          users.${user} = {
            enable = true;
            files.".config/foo".text = "managed content";
          };
        };

        # Drops the managed file, forcing smfh to deactivate the old entry on the
        # next switch. If that entry has drifted on disk, deactivation aborts.
        specialisation.fileRemoved.configuration = {
          eigenhome.users.${user}.files.".config/foo".enable = false;
        };
      };
    };

    testScript = {nodes, ...}: let
      baseSystem = nodes.node1.system.build.toplevel;
      specialisations = "${baseSystem}/specialisation";
    in ''
      node1.succeed("loginctl enable-linger ${user}")

      with subtest("Baseline established with the managed file"):
          node1.succeed("${baseSystem}/bin/switch-to-configuration test")
          node1.succeed("test -L ${userHome}/.config/foo")
          node1.succeed("grep -qF '.config/foo' ${manifest}")

      with subtest("Drift makes smfh deactivation fail during the switch"):
          # Point the managed symlink at an unrelated real file so smfh's check()
          # reports Ok(false) and deactivate() aborts with
          # "File is not the same as expected" (smfh-core file_util.rs).
          node1.succeed("echo drift > /tmp/drift && chmod 644 /tmp/drift")
          node1.succeed("ln -sfn /tmp/drift ${userHome}/.config/foo")
          node1.execute("${specialisations}/fileRemoved/bin/switch-to-configuration test")
          node1.succeed(
              "[ \"$(systemctl show eigenhome-activate@${user}.service -p Result --value)\" != success ]"
          )

      with subtest("Failed activation must NOT advance the manifest baseline"):
          # copy Requires= activate, so a failed activation blocks the manifest copy.
          # The baseline must still record the file; otherwise the desync becomes
          # silent and permanent (manifest-to-manifest diff never sees it again).
          node1.succeed("grep -qF '.config/foo' ${manifest}")

      with subtest("Baseline advances once the drift is resolved"):
          node1.succeed("rm ${userHome}/.config/foo")
          node1.succeed("systemctl start eigenhome-copy@${user}.service")
          node1.succeed(
              "[ \"$(systemctl show eigenhome-activate@${user}.service -p Result --value)\" = success ]"
          )
          node1.fail("grep -qF '.config/foo' ${manifest}")
    '';
  }

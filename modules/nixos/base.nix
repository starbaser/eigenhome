{
  config,
  hjem-lib,
  lib,
  options,
  pkgs,
  utils,
  ...
}: let
  inherit (builtins) attrNames attrValues concatLists concatMap concatStringsSep filter mapAttrs toJSON typeOf;
  inherit (hjem-lib) fileToJson;
  inherit (lib.attrsets) filterAttrs optionalAttrs;
  inherit (lib.modules) importApply mkDefault mkIf mkMerge;
  inherit (lib.strings) optionalString;
  inherit (lib.trivial) flip pipe;
  inherit (lib.types) submoduleWith;
  inherit (lib.meta) getExe;

  osConfig = config;

  cfg = config.eigenhome;
  _class = "nixos";

  enabledUsers = filterAttrs (_: u: u.enable) cfg.users;
  disabledUsers = filterAttrs (_: u: !u.enable) cfg.users;

  userFiles = user: [
    user.files
    user.xdg.cache.files
    user.xdg.config.files
    user.xdg.data.files
    user.xdg.state.files
  ];

  linker = getExe cfg.linker;

  newManifests = let
    writeManifest = username: let
      name = "manifest-${username}.json";
    in
      pkgs.writeTextFile {
        inherit name;
        destination = "/${name}";
        text = toJSON {
          version = 3;
          files = concatMap (
            flip pipe [
              attrValues
              (filter (x: x.enable))
              (map fileToJson)
            ]
          ) (userFiles cfg.users.${username});
        };
        checkPhase = ''
          set -e
          CUE_CACHE_DIR=$(pwd)/.cache
          CUE_CONFIG_DIR=$(pwd)/.config

          ${getExe pkgs.cue} vet -c ${../../manifest/v3.cue} $target
        '';
      };
  in
    pkgs.symlinkJoin
    {
      name = "eigenhome-manifests";
      paths = map writeManifest (attrNames enabledUsers);
    };

  eigenhomeSubmodule = submoduleWith {
    description = "eigenhome submodule for NixOS";
    class = "eigenhome";
    specialArgs =
      cfg.specialArgs
      // {
        inherit hjem-lib osConfig pkgs utils;
        osOptions = options;
      };
    modules =
      concatLists
      [
        [
          ../common/user.nix
          ./systemd.nix
          ({
            config,
            name,
            ...
          }: let
            user = osConfig.users.users.${name};
          in {
            assertions = [
              {
                assertion = config.enable -> user.enable;
                message = "Enabled eigenhome user '${name}' must also be configured and enabled in NixOS.";
              }
            ];

            user = mkDefault user.name;
            directory = mkDefault user.home;
          })
        ]
        cfg.extraModules
      ];
  };
in {
  inherit _class;

  imports = [
    (importApply ../common/top-level.nix {inherit eigenhomeSubmodule _class;})
  ];

  config = mkMerge [
    (mkIf (cfg.linker == null) {
      systemd.user.tmpfiles.users =
        mapAttrs (_: u: {
          rules = pipe (userFiles u) [
            (concatMap attrValues)
            (filter (f: f.enable && f.source != null))
            (map (
              file:
              # L+ will recreate, i.e., clobber existing files.
              "L${optionalString file.clobber "+"} '${file.target}' - - - - ${file.source}"
            ))
          ];
        })
        enabledUsers;
    })

    (mkIf (cfg.linker != null) {
      /*
      The different eigenhome services expect the manifest to be generated under `/var/lib/eigenhome/manifest-{user}.json`.
      */
      systemd.targets.eigenhome = {
        description = "eigenhome File Management";
        after = ["local-fs.target"];
        wantedBy = ["sysinit-reactivation.target" "multi-user.target"];
        before = ["sysinit-reactivation.target"];
        requires = let
          requiredUserServices = name: [
            "eigenhome-activate@${name}.service"
            "eigenhome-copy@${name}.service"
          ];
        in
          concatMap requiredUserServices (attrNames enabledUsers)
          ++ ["eigenhome-cleanup.service"];
      };

      systemd.services = let
        oldManifests = "/var/lib/eigenhome";
        checkEnabledUsers = ''
          case "$1" in
            ${concatStringsSep "|" (attrNames enabledUsers)}) ;;
            *) echo "User '%i' is not configured for eigenhome" >&2; exit 0 ;;
          esac
        '';
      in
        optionalAttrs (enabledUsers != {}) {
          eigenhome-prepare = {
            description = "Prepare eigenhome manifests directory";
            enableStrictShellChecks = true;
            script = "mkdir -p ${oldManifests}";
            serviceConfig.Type = "oneshot";
            unitConfig.RefuseManualStart = true;
          };

          "eigenhome-activate@" = {
            description = "Link files for %i from their manifest";
            enableStrictShellChecks = true;
            serviceConfig = {
              User = "%i";
              Type = "oneshot";
            };
            requires = [
              "eigenhome-prepare.service"
              "eigenhome-copy@%i.service"
            ];
            after = ["eigenhome-prepare.service"];
            scriptArgs = "%i";
            script = let
              linkerOpts =
                if (typeOf cfg.linkerOptions == "set")
                then ''--linker-opts "${toJSON cfg.linkerOptions}"''
                else concatStringsSep " " cfg.linkerOptions;
            in ''
              ${checkEnabledUsers}
              new_manifest="${newManifests}/manifest-$1.json"
              old_manifest="${oldManifests}/manifest-$1.json"

              if [ ! -f "$old_manifest" ]; then
                ${linker} ${linkerOpts} activate "$new_manifest"
                exit 0
              fi

              ${linker} ${linkerOpts} diff "$new_manifest" "$old_manifest"
            '';
          };

          "eigenhome-copy@" = {
            description = "Copy the manifest into eigenhome's state directory for %i";
            enableStrictShellChecks = true;
            serviceConfig.Type = "oneshot";
            after = ["eigenhome-activate@%i.service"];
            scriptArgs = "%i";
            script = ''
              ${checkEnabledUsers}
              new_manifest="${newManifests}/manifest-$1.json"

              if ! cp "$new_manifest" ${oldManifests}; then
                echo "Copying the manifest for $1 failed. This is likely due to using the previous\
                version of the manifest handling. The manifest directory has been recreated and repopulated with\
                %i's manifest. Please re-run the activation services for your other users, if you have ran this one manually."

                rm -rf ${oldManifests}
                mkdir -p ${oldManifests}

                cp "$new_manifest" ${oldManifests}
              fi
            '';
          };

          eigenhome-cleanup = {
            description = "Cleanup disabled users' manifests";
            enableStrictShellChecks = true;
            serviceConfig.Type = "oneshot";
            after = ["eigenhome.target"];
            unitConfig.RefuseManualStart = false;
            script = let
              manifestsToDelete =
                map
                (user: "${oldManifests}/manifest-${user}.json")
                (attrNames disabledUsers);
            in
              if disabledUsers != {}
              then "rm -f ${concatStringsSep " " manifestsToDelete}"
              else "true";
          };
        };
    })
  ];
}

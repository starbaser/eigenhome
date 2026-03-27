# The common module that contains eigenhome's per-user options. To ensure eigenhome remains
# somewhat compliant with cross-platform paradigms (e.g. NixOS or Darwin.) Platform
# specific options such as nixpkgs module system or nix-darwin module system should
# be avoided here.
{
  config,
  clobberByDefault ? false,
  hjem-lib,
  lib,
  name,
  options,
  pkgs,
  ...
}: let
  inherit (hjem-lib) envVarType listOrSingletonOf toEnv;
  inherit (lib.attrsets) attrValues filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.lists) any;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.strings) concatLines concatStringsSep;
  inherit (lib.trivial) id;
  inherit (lib.types) attrsOf attrsWith bool listOf package passwdEntry path str strMatching;

  cfg = config;

  mkFileType = dir:
    attrsWith {
      elemType = hjem-lib.mkFileEntry {
        baseDir = dir;
        defaultClobber = cfg.clobberFiles;
        defaultClobberText = literalExpression "config.eigenhome.users.${name}.clobberFiles";
      };
      placeholder = "path";
    };

  fileAssertions = prefix: files:
    lib.concatLists (mapAttrsToList (fname: f: [
      {
        assertion = f.permissions == null || builtins.elem f.type ["copy" "delete" "directory" "modify"];
        message = "${prefix}.\"${fname}\": 'permissions' requires type copy/delete/directory/modify, got '${f.type}'";
      }
      {
        assertion = f.uid == null || builtins.elem f.type ["copy" "delete" "directory" "modify"];
        message = "${prefix}.\"${fname}\": 'uid' requires type copy/delete/directory/modify, got '${f.type}'";
      }
      {
        assertion = f.gid == null || builtins.elem f.type ["copy" "delete" "directory" "modify"];
        message = "${prefix}.\"${fname}\": 'gid' requires type copy/delete/directory/modify, got '${f.type}'";
      }
    ]) (filterAttrs (_: f: f.enable) files));
in {
  _class = "eigenhome";

  imports = [
    # Makes "assertions" option available without having to duplicate the work
    # already done in the Nixpkgs module.
    (pkgs.path + "/nixos/modules/misc/assertions.nix")
  ];

  options = {
    enable =
      mkEnableOption "home management for this user"
      // {
        default = true;
        example = false;
      };

    user = mkOption {
      type = strMatching "[a-zA-Z0-9_.][a-zA-Z0-9_.-]*";
      description = "The owner of a given home directory.";
    };

    directory = mkOption {
      type = passwdEntry path;
      description = ''
        The home directory for the user, to which files configured in
        {option}`eigenhome.users.<username>.files` will be relative to by default.
      '';
    };

    clobberFiles = mkOption {
      type = bool;
      default = clobberByDefault;
      example = true;
      description = ''
        The default override behaviour for files managed by eigenhome for a
        particular user.

        Per-file behaviour can be modified with
        {option}`eigenhome.users.<username>.files.<path>.clobber`.
      '';
    };

    files = mkOption {
      default = {};
      type = mkFileType cfg.directory;
      example = {".config/foo.txt".source = "Hello World";};
      description = "eigenhome-managed files.";
    };

    xdg = {
      cache = {
        directory = mkOption {
          type = path;
          default = "${cfg.directory}/.cache";
          defaultText = "$HOME/.cache";
          description = ''
            The XDG cache directory for the user, to which files configured in
            {option}`eigenhome.users.<username>.xdg.cache.files` will be relative to by default.

            Adds {env}`XDG_CACHE_HOME` to {option}`environment.sessionVariables` for
            this user if changed.
          '';
        };
        files = mkOption {
          default = {};
          type = mkFileType cfg.xdg.cache.directory;
          example = {"foo.txt".source = "Hello World";};
          description = "eigenhome-managed cache files.";
        };
      };

      config = {
        directory = mkOption {
          type = path;
          default = "${cfg.directory}/.config";
          defaultText = "$HOME/.config";
          description = ''
            The XDG config directory for the user, to which files configured in
            {option}`eigenhome.users.<username>.xdg.config.files` will be relative to by default.

            Adds {env}`XDG_CONFIG_HOME` to {option}`environment.sessionVariables` for
            this user if changed.
          '';
        };
        files = mkOption {
          default = {};
          type = mkFileType cfg.xdg.config.directory;
          example = {"foo.txt".source = "Hello World";};
          description = "eigenhome-managed config files.";
        };
      };

      data = {
        directory = mkOption {
          type = path;
          default = "${cfg.directory}/.local/share";
          defaultText = "$HOME/.local/share";
          description = ''
            The XDG data directory for the user, to which files configured in
            {option}`eigenhome.users.<username>.xdg.data.files` will be relative to by default.

            Adds {env}`XDG_DATA_HOME` to {option}`environment.sessionVariables` for
            this user if changed.
          '';
        };
        files = mkOption {
          default = {};
          type = mkFileType cfg.xdg.data.directory;
          example = {"foo.txt".source = "Hello World";};
          description = "eigenhome-managed data files.";
        };
      };

      state = {
        directory = mkOption {
          type = path;
          default = "${cfg.directory}/.local/state";
          defaultText = "$HOME/.local/state";
          description = ''
            The XDG state directory for the user, to which files configured in
            {option}`eigenhome.users.<username>.xdg.state.files` will be relative to by default.

            Adds {env}`XDG_STATE_HOME` to {option}`environment.sessionVariables` for
            this user if changed.
          '';
        };
        files = mkOption {
          default = {};
          type = mkFileType cfg.xdg.state.directory;
          example = {"foo.txt".source = "Hello World";};
          description = "eigenhome-managed state files.";
        };
      };

      mime-apps = {
        added-associations = mkOption {
          type = attrsOf (listOrSingletonOf str);
          default = {};
          example = {
            mimetype1 = ["foo1.desktop" "foo2.desktop" "foo3.desktop"];
            mimetype2 = "foo4.desktop";
          };
          description = ''
            Defines additional [associations] of applications with mimetypes, as
            if the `.desktop` file was listing this mimetype in the first place.

            [associations]: https://specifications.freedesktop.org/mime-apps/latest/associations.html
          '';
        };

        removed-associations = mkOption {
          type = attrsOf (listOrSingletonOf str);
          default = {};
          example = {
            mimetype1 = "foo5.desktop";
          };
          description = ''
            Removes [associations] of applications with mimetypes, as if the
            `.desktop` file was NOT listing this mimetype in the first place.

            [associations]: https://specifications.freedesktop.org/mime-apps/latest/associations.html
          '';
        };

        default-applications = mkOption {
          type = attrsOf (listOrSingletonOf str);
          default = {};
          example = {
            mimetype1 = ["default1.desktop" "default2.desktop"];
          };
          description = ''
            Indicates the [default application] to be used for a given mimetype.

            [default application]: https://specifications.freedesktop.org/mime-apps/latest/default.html
          '';
        };
      };
    };

    packages = mkOption {
      type = listOf package;
      default = [];
      example = literalExpression "[pkgs.hello]";
      description = "Packages to install for this user.";
    };

    environment = {
      loadEnv = mkOption {
        type = path;
        readOnly = true;
        description = ''
          A POSIX compliant shell script containing the user session variables needed to bootstrap the session.

          As there is no reliable and agnostic way of setting session variables, eigenhome's
          environment module does nothing by itself. Rather, it provides a POSIX compliant shell script
          that needs to be sourced where needed.
        '';
      };
      sessionVariables = mkOption {
        type = envVarType;
        default = {};
        example = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
        description = ''
          A set of environment variables used in the user environment.
          If a list of strings is used, they will be concatenated with colon
          characters.
        '';
      };
    };
  };

  config = {
    # for docs
    _module.args.name = lib.mkDefault "‹username›";

    environment = {
      sessionVariables = {
        XDG_CACHE_HOME = mkIf (cfg.xdg.cache.directory != options.xdg.cache.directory.default) cfg.xdg.cache.directory;
        XDG_CONFIG_HOME = mkIf (cfg.xdg.config.directory != options.xdg.config.directory.default) cfg.xdg.config.directory;
        XDG_DATA_HOME = mkIf (cfg.xdg.data.directory != options.xdg.data.directory.default) cfg.xdg.data.directory;
        XDG_STATE_HOME = mkIf (cfg.xdg.state.directory != options.xdg.state.directory.default) cfg.xdg.state.directory;
      };
      loadEnv = lib.pipe cfg.environment.sessionVariables [
        (mapAttrsToList (name: value: "export ${name}=\"${toEnv value}\""))
        concatLines
        (pkgs.writeShellScript "load-env")
      ];
    };

    xdg.config.files."mimeapps.list" = let
      nonDefault = {
        added = cfg.xdg.mime-apps.added-associations != options.xdg.mime-apps.added-associations.default;
        removed = cfg.xdg.mime-apps.removed-associations != options.xdg.mime-apps.removed-associations.default;
        default = cfg.xdg.mime-apps.default-applications != options.xdg.mime-apps.default-applications.default;
      };
      ini = pkgs.formats.ini {listToValue = concatStringsSep ";";};
    in
      mkIf (any id (attrValues nonDefault)) {
        source = ini.generate "mimeapps.list" (
          {}
          // lib.optionalAttrs nonDefault.added {"Added Associations" = cfg.xdg.mime-apps.added-associations;}
          // lib.optionalAttrs nonDefault.removed {"Removed Associations" = cfg.xdg.mime-apps.removed-associations;}
          // lib.optionalAttrs nonDefault.default {"Default Applications" = cfg.xdg.mime-apps.default-applications;}
        );
      };

    assertions =
      fileAssertions "files" cfg.files
      ++ fileAssertions "xdg.cache.files" cfg.xdg.cache.files
      ++ fileAssertions "xdg.config.files" cfg.xdg.config.files
      ++ fileAssertions "xdg.data.files" cfg.xdg.data.files
      ++ fileAssertions "xdg.state.files" cfg.xdg.state.files;
  };
}

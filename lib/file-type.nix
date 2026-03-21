# eigenhome file entry submodule factory
#
# Produces a submodule type for declaring managed files. Each entry describes
# a single file operation (symlink, copy, delete, directory, or modify).
#
# Type constraints (e.g. permissions only valid for copy/delete/directory/modify)
# are enforced via NixOS assertions in the per-user module, not at the type level.
# This reports ALL violations at once instead of crashing on the first.
{
  lib,
  pkgs,
}: {
  baseDir,
  defaultClobber,
  defaultClobberText,
}:
  lib.types.submodule (
    {
      name,
      config,
      options,
      ...
    }: {
      options = {
        enable =
          lib.mkEnableOption "creation of this file"
          // {
            default = true;
            example = false;
          };

        type = lib.mkOption {
          type = lib.types.enum [
            "symlink"
            "copy"
            "delete"
            "directory"
            "modify"
          ];
          default = "symlink";
          description = "Type of file operation to perform.";
        };

        target = lib.mkOption {
          type = lib.types.str;
          defaultText = name;
          apply = p:
            if lib.hasPrefix "/" p
            then throw "eigenhome: absolute paths are not supported in file targets"
            else "${config.relativeTo}/${p}";
          description = ''
            Path to the target file, relative to the base directory.
          '';
        };

        text = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = "Text content of the file.";
        };

        source = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to the source file or directory.";
        };

        permissions = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[0-7]{3,4}");
          default = null;
          description = "Octal permissions to set on the target path.";
        };

        uid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "User ID to set as owner on the target path.";
        };

        gid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Group ID to set as owner on the target path.";
        };

        executable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to set the execute bit on the target file.";
        };

        clobber = lib.mkOption {
          type = lib.types.bool;
          default = defaultClobber;
          defaultText = defaultClobberText;
          description = ''
            Whether to overwrite existing files at the target path.

            When using systemd-tmpfiles, this controls whether rules use
            `L+` (recreate) instead of `L` (create).
          '';
        };

        recursive = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            When true and source is a directory, each file within is
            symlinked individually rather than symlinking the directory
            itself. Expansion happens at build time.
          '';
        };

        onChange = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Shell commands to run after the file has been linked.
            Runs on each activation when set.
          '';
        };

        relativeTo = lib.mkOption {
          internal = true;
          type = lib.types.path;
          default = baseDir;
          description = "Base directory that targets are resolved relative to.";
          apply = p:
            assert lib.hasPrefix "/" p || builtins.abort "eigenhome: relativeTo must be absolute: ${p}";
              p;
        };
      };

      config = {
        target = lib.mkDefault name;

        source = lib.mkIf (config.text != null) (
          lib.mkDerivedConfig options.text (text:
            pkgs.writeTextFile {
              inherit name text;
              inherit (config) executable;
            })
        );
      };
    }
  )

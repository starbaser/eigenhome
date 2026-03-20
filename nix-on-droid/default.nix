# nix-on-droid platform backend for eigenhome.
#
# Provides the eigenhome.* option namespace inside nix-on-droid's module system.
# Routes eigenhome options (files, packages, session variables, services) to
# nix-on-droid primitives (build.activation, environment.packages, etc.).
#
# nix-on-droid is single-user and has no systemd. File deployment is done via
# activation scripts, and systemd services are translated to wrapper scripts.
{eigenhome}: {
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  inherit (builtins) concatLists;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.options) literalExpression mkOption;
  inherit (lib.types) attrs attrsWith bool listOf raw submoduleWith;

  hjem-lib = import "${eigenhome}/lib" {inherit lib pkgs;};

  cfg = config.eigenhome;
  enabledUsers = filterAttrs (_: u: u.enable) cfg.users;

  # Minimal systemd option stubs for nix-on-droid.
  #
  # eigenhome's modules/nixos/systemd.nix depends on NixOS-only utils.systemdUtils,
  # so we provide lightweight stubs that absorb writes from eigenhome's
  # systemd-bridge without generating unit files.
  systemdStub = {lib, ...}: let
    inherit (lib) mkEnableOption mkOption;
    inherit (lib.types) anything attrsOf;
  in {
    options.systemd = {
      enable =
        mkEnableOption "systemd unit management (stubbed on nix-on-droid)"
        // {default = false;};
      units = mkOption {
        type = attrsOf anything;
        default = {};
        internal = true;
      };
      services = mkOption {
        type = attrsOf anything;
        default = {};
      };
      timers = mkOption {
        type = attrsOf anything;
        default = {};
      };
      paths = mkOption {
        type = attrsOf anything;
        default = {};
      };
      sockets = mkOption {
        type = attrsOf anything;
        default = {};
      };
      targets = mkOption {
        type = attrsOf anything;
        default = {};
      };
      slices = mkOption {
        type = attrsOf anything;
        default = {};
      };
    };
  };

  eigenhomeSubmodule = submoduleWith {
    description = "eigenhome submodule for nix-on-droid";
    class = "eigenhome";
    specialArgs =
      cfg.specialArgs
      // {
        inherit hjem-lib pkgs;
        osConfig = config;
        nixosConfig = null;
        darwinConfig = null;
        osOptions = options;
      };
    modules =
      [
        "${eigenhome}/modules/common/user.nix"
        systemdStub
        ./service-bridge.nix
        ({...}: {
          user = mkDefault config.user.userName;
          directory = mkDefault config.user.home;
        })
      ]
      ++ cfg.extraModules;
  };
in {
  imports = [
    ./file-activation.nix
  ];

  options.eigenhome = {
    users = mkOption {
      default = {};
      type = attrsWith {
        elemType = eigenhomeSubmodule;
        placeholder = "username";
      };
      description = "eigenhome-managed user configurations.";
    };

    extraModules = mkOption {
      type = listOf raw;
      default = [];
      description = ''
        Additional modules evaluated under each user in {option}`eigenhome.users`.
      '';
    };

    specialArgs = mkOption {
      type = attrs;
      default = {};
      example = literalExpression "{ inherit inputs; }";
      description = ''
        Additional `specialArgs` passed to all eigenhome user modules.
      '';
    };
  };

  config = mkIf (enabledUsers != {}) {
    environment.packages =
      concatLists (mapAttrsToList (_: u: u.packages) enabledUsers);

    environment.sessionVariables =
      mkMerge (mapAttrsToList (_: u: u.environment.sessionVariables) enabledUsers);

    build.activation =
      mkMerge (mapAttrsToList (_: u: u._nodOneshotActivations) enabledUsers);

    assertions =
      concatLists
      (mapAttrsToList (
          user: userCfg:
            map ({
              assertion,
              message,
              ...
            }: {
              inherit assertion;
              message = "${user} profile: ${message}";
            })
            userCfg.assertions
        )
        enabledUsers);

    warnings =
      concatLists
      (mapAttrsToList (
          user: v:
            map (
              warning: "${user} profile: ${warning}"
            )
            v.warnings
        )
        enabledUsers);
  };
}

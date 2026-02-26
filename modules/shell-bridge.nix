# Shell bridge: routes HM shell writes to rum modules or standalone config files.
# Two modes:
#   1. Rum bridge — if rum.programs.<shell>.enable is true, append via mkAfter
#   2. Standalone fallback — write sourceable fragments to XDG config files
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    mkAfter
    mkIf
    optionalString
    ;

  # Safe rum detection: returns false when rum modules aren't loaded (path missing),
  # false when disabled, true when enabled.
  rumEnabled = path: lib.attrByPath (path ++ [ "enable" ]) false config;

  # Merge global + per-shell aliases into shell-appropriate syntax.
  allAliases = shell:
    config.home.shellAliases
    // (lib.attrByPath [ "programs" shell "shellAliases" ] { } config);

  aliasLines = shell:
    concatStringsSep "\n" (
      mapAttrsToList (n: v: "alias ${n}=${lib.escapeShellArg v}") (allAliases shell)
    );

  fishAliasLines =
    concatStringsSep "\n" (
      mapAttrsToList (n: v: "alias -- ${lib.escapeShellArg n} ${lib.escapeShellArg v}") (allAliases "fish")
    );

  fishAbbrLines =
    concatStringsSep "\n" (
      mapAttrsToList (n: v: "abbr --add -- ${lib.escapeShellArg n} ${lib.escapeShellArg v}") config.programs.fish.shellAbbrs
    );

  # Content aggregators per shell.
  zsh = {
    hasContent =
      config.programs.zsh.initContent != ""
      || config.programs.zsh.initExtra != ""
      || (allAliases "zsh") != { };
    content = concatStringsSep "\n" [
      (optionalString ((allAliases "zsh") != { }) (aliasLines "zsh"))
      config.programs.zsh.initContent
      config.programs.zsh.initExtra
    ];
  };

  zshEnv = {
    hasContent = config.programs.zsh.envExtra != "";
    content = config.programs.zsh.envExtra;
  };

  zshLogin = {
    hasContent = config.programs.zsh.loginExtra != "";
    content = config.programs.zsh.loginExtra;
  };

  zshLogout = {
    hasContent = config.programs.zsh.logoutExtra != "";
    content = config.programs.zsh.logoutExtra;
  };

  bash = {
    hasContent =
      config.programs.bash.initExtra != ""
      || config.programs.bash.bashrcExtra != ""
      || (allAliases "bash") != { };
    content = concatStringsSep "\n" [
      (optionalString ((allAliases "bash") != { }) (aliasLines "bash"))
      config.programs.bash.initExtra
      config.programs.bash.bashrcExtra
    ];
  };

  bashProfile = {
    hasContent = config.programs.bash.profileExtra != "";
    content = config.programs.bash.profileExtra;
  };

  fish = {
    hasInteractive =
      config.programs.fish.interactiveShellInit != ""
      || config.programs.fish.shellInitLast != ""
      || (allAliases "fish") != { }
      || config.programs.fish.shellAbbrs != { };
    interactiveContent = concatStringsSep "\n" [
      (optionalString ((allAliases "fish") != { }) fishAliasLines)
      (optionalString (config.programs.fish.shellAbbrs != { }) fishAbbrLines)
      config.programs.fish.interactiveShellInit
      config.programs.fish.shellInitLast
    ];
    hasInit = config.programs.fish.shellInit != "";
    initContent = config.programs.fish.shellInit;
    hasLogin = config.programs.fish.loginShellInit != "";
    loginContent = config.programs.fish.loginShellInit;
  };

  nushell = {
    hasConfig = config.programs.nushell.extraConfig != "";
    configContent = config.programs.nushell.extraConfig;
    hasEnv = config.programs.nushell.extraEnv != "";
    envContent = config.programs.nushell.extraEnv;
  };

  rumZsh = rumEnabled [ "rum" "programs" "zsh" ];
  rumFish = rumEnabled [ "rum" "programs" "fish" ];
  rumNushell = rumEnabled [ "rum" "programs" "nushell" ];
in
{
  config = {
    # --- Zsh routing ---
    rum.programs.zsh.initConfig = mkIf (rumZsh && zsh.hasContent) (mkAfter zsh.content);

    # Standalone zsh fallback (when rum zsh is not active)
    xdg.config.files = lib.mkMerge [
      (mkIf (!rumZsh && zsh.hasContent) {
        "zsh/hm-compat.zsh".text = zsh.content;
      })
      (mkIf (!rumZsh && zshEnv.hasContent) {
        "zsh/hm-compat-env.zsh".text = zshEnv.content;
      })
      (mkIf (zshLogin.hasContent) {
        "zsh/hm-compat-login.zsh".text = zshLogin.content;
      })
      (mkIf (zshLogout.hasContent) {
        "zsh/hm-compat-logout.zsh".text = zshLogout.content;
      })

      # Zsh env via rum (loginConfig doesn't include env, so use standalone for env)
      (mkIf (rumZsh && zshEnv.hasContent) {
        "zsh/hm-compat-env.zsh".text = zshEnv.content;
      })

      # --- Bash routing (no rum module — always standalone) ---
      (mkIf (bash.hasContent) {
        "bash/hm-compat.sh".text = bash.content;
      })
      (mkIf (bashProfile.hasContent) {
        "bash/hm-compat-profile.sh".text = bashProfile.content;
      })

      # --- Fish routing ---
      # Fish conf.d auto-sources — zero-config for fish users
      (mkIf (!rumFish && fish.hasInteractive) {
        "fish/conf.d/hm-compat.fish".text = fish.interactiveContent;
      })
      (mkIf (!rumFish && fish.hasInit) {
        "fish/conf.d/hm-compat-init.fish".text = fish.initContent;
      })
      (mkIf (!rumFish && fish.hasLogin) {
        "fish/conf.d/hm-compat-login.fish".text = fish.loginContent;
      })

      # --- Nushell routing ---
      (mkIf (!rumNushell && nushell.hasConfig) {
        "nushell/hm-compat.nu".text = nushell.configContent;
      })
      (mkIf (!rumNushell && nushell.hasEnv) {
        "nushell/hm-compat-env.nu".text = nushell.envContent;
      })

      # --- Ion (always standalone, no rum module) ---
      (mkIf (config.programs.ion.initExtra != "") {
        "ion/hm-compat.ion".text = config.programs.ion.initExtra;
      })
    ];

    # --- Fish rum bridge ---
    rum.programs.fish.config = mkIf (rumFish && (fish.hasInteractive || fish.hasInit)) (
      mkAfter (
        concatStringsSep "\n" [
          fish.initContent
          fish.interactiveContent
        ]
      )
    );

    rum.programs.fish.earlyConfigFiles = mkIf (rumFish && fish.hasLogin) {
      "hm-compat-login" = fish.loginContent;
    };

    # --- Nushell rum bridge ---
    rum.programs.nushell.extraConfig =
      mkIf (rumNushell && nushell.hasConfig) (mkAfter nushell.configContent);

    rum.programs.nushell.envFile =
      mkIf (rumNushell && nushell.hasEnv) (mkAfter nushell.envContent);

    # --- Per-shell session variables → home.sessionVariables ---
    home.sessionVariables = lib.mkMerge [
      (mkIf (config.programs.bash.sessionVariables != { }) config.programs.bash.sessionVariables)
      (mkIf (config.programs.zsh.sessionVariables != { }) config.programs.zsh.sessionVariables)
    ];
  };
}

# `eigenhome` - `$HOME` is the eigenvector.

Declarative home directory management for NixOS. `eigenhome` unifies the vast catalog of 1000+ [Home Manager](https://github.com/nix-community/home-manager) modules with the refined, streamlined interface of [hjem](https://github.com/feel-co/hjem). One config, no transformation.

## Installation

> [!IMPORTANT]
> Use at your own risk, and beware of bugs, issues, and missing features. If you do not feel like being a beta tester, wait until `eigenhome` is more finished.

Replace your `home-manager` or `hjem` flake input with `eigenhome`:

```diff
 # ~/.config/nixos/flake.nix
  inputs = {
-   hjem.url = "github:feel-co/hjem";
-   home-manager.url = "github:nix-community/home-manager";
-   home-manager.inputs.nixpkgs.follows = "nixpkgs";
+   eigenhome.url = "github:starbaser/eigenhome";
  };
```

Then:
1. Replace your module import with `eigenhome.nixosModules.default`
2. **From hjem:** add `eigenhome.nixosModules.hjem-compat` to keep the `hjem.*` namespace, or find-and-replace `hjem.` → `eigenhome.`. If you use `generator`/`value`, see [here](#hjem-migration)
3. **From Home Manager:** replace `home-manager.users.<name>` with `eigenhome.users.<name>` and add `eigenhome.homeModules.hm-compat` to your user imports.

4. Build and verify your configuration evaluates:

```bash
# Update the lock file with the new input
nix flake lock --update-input eigenhome

# Dry-run build — evaluates the config without activating anything
nixos-rebuild build --flake ~/.config/nixos
```

Before continuing, please carefully read the following:

> [!CAUTION]
> The linker that `eigenhome`/`hjem` uses (smfh) replaces managed file paths with symlinks to the nix store. If you have non-symlinked files at those paths, they will be overwritten. The `build` step is safe — only `switch` modifies your home directory. Back up first if unsure.
> To see exactly which files will be managed, inspect the manifest after `build`:
> ```bash
> # Find the manifest store path from the built service unit
> grep -oP '/nix/store/[^"]+eigenhome-manifests' \
>   result/etc/systemd/system/eigenhome-activate@.service | head -1
>
> # List every target path smfh will manage
> jq -r '.files[].target' /nix/store/<hash>-eigenhome-manifests/manifest-<username>.json
> ```
>
> To back up files before they are replaced with symlinks:
> ```bash
> MANIFEST=$(grep -oP '/nix/store/[^"]+eigenhome-manifests' \
>   result/etc/systemd/system/eigenhome-activate@.service | head -1)
> mkdir -p ~/eigenhome-backup
> jq -r '.files[].target' "$MANIFEST"/manifest-*.json \
>   | while read -r f; do [ -e "$f" ] && cp --parents "$f" ~/eigenhome-backup/; done
> ```
> If you're extra cautious — snapshot all of `~/.config` with permissions intact:
> ```bash
> tar czpf ~/config-backup-$(date +%Y%m%d).tar.gz -C ~ .config
> ```


**Switch when ready:**
```bash
sudo nixos-rebuild switch --flake ~/.config/nixos
```

If your config doesn't evaluate cleanly after these steps, [open an issue](https://github.com/starbaser/eigenhome/issues) — it's a bug and I'll fix it along with your config.

## Quick Start

Your home, your way. Choose [`hjem`-style](https://github.com/feel-co/hjem#implementation) for the dining room and keep Home Manager in the backyard.

```nix
eigenhome.users.alice = {
  enable = true;

  files.".config/app/config.toml".text = ''
    [settings]
    theme = "dark"
  '';

  files.".local/bin/myscript" = {
    source = ./scripts/myscript.sh;
    executable = true;
  };

  files.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  packages = [ pkgs.git pkgs.htop ];

  environment.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
  };
};
```

### XDG directories

```nix
eigenhome.users.alice = {
  enable = true;

  xdg.config.files."alacritty/alacritty.toml".source = ./alacritty.toml;
  xdg.data.files."applications/myapp.desktop".text = "...";
  xdg.cache.files."myapp/init".text = "";
  xdg.state.files."myapp/state.json".text = "{}";
};
```

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    eigenhome.url = "github:starbaser/eigenhome";

    # Your home manager inputs stay unchanged.

    firefox-config = {
      url = "github:starbaser/firefox-config"; # My custom firefox-nightly flake
      inputs.eigenhome.follows = "eigenhome";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, eigenhome, firefox-config, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        eigenhome.nixosModules.default

        ({ pkgs, ... }: {
          # Load HM compat for all users
          eigenhome.extraModules = [ eigenhome.homeModules.hm-compat ];

          eigenhome.users.alice = {
            enable = true;
            imports = [
              firefox-config.homeModules.firefox  # programs.firefox.*
            ];

            # Native hjem — deploy files directly
            files.".local/bin/rebuild" = {
              source = ./scripts/rebuild.sh;
              executable = true;
            };
            xdg.config.files."gtk-3.0/settings.ini".text = ''
              [Settings]
              gtk-theme-name=adw-gtk3-dark
              gtk-icon-theme-name=Papirus-Dark
            '';
            xdg.config.files."mimeapps.list".text = ''
              [Default Applications]
              text/html=firefox.desktop
              x-scheme-handler/https=firefox.desktop
            '';
            xdg.data.files."applications/open-terminal.desktop".text = ''
              [Desktop Entry]
              Name=Terminal
              Exec=kitty
              Type=Application
            '';

            # Home Manager programs
            programs.git = {
              enable = true;
              userName = "Alice";
              userEmail = "alice@example.com";
              aliases = { co = "checkout"; st = "status"; };
              ignores = [ "*.swp" ".direnv" "result" ];
              extraConfig.init.defaultBranch = "main";
            };
            programs.starship.enable = true;
            programs.direnv = {
              enable = true;
              nix-direnv.enable = true;
            };
            programs.bat = {
              enable = true;
              config.theme = "OneHalfDark";
            };
            programs.fzf.enable = true;
            programs.zoxide.enable = true;

            # Packages and environment
            packages = with pkgs; [ htop ripgrep fd eza ];
            environment.sessionVariables = {
              EDITOR = "nvim";
              PAGER = "bat --plain";
            };
          };
        })
      ];
    };
  };
}
```

### `hm-compat`

The substrate of `eigenhome` is the `hm-compat` compatibility layer — it wraps Home Manager's upstream modules and evaluates them within a perfectly replicated `hjem` module system. Load it globally with `extraModules` (as above), or per-user via `imports`:

```nix
eigenhome.users.alice = {
  enable = true;
  imports = [ eigenhome.homeModules.hm-compat ];
};
```

#### Custom Home Manager Module Compatibility

The compatibility layer includes a curated set of HM program modules. To use an HM module not in that set, wrap it manually with `wrapHmModule`, which is available as a module argument when `hm-compat` is imported:

```nix
eigenhome.users.alice = {
  enable = true;
  imports = [
    eigenhome.homeModules.hm-compat

    # Wrap an HM module by source path
    ({ wrapHmModule, hmSrc, ... }: {
      imports = [ (wrapHmModule "${hmSrc}/modules/programs/taskwarrior.nix") ];
    })

    # Wrap a flake's homeModule output
    ({ wrapHmModule, ... }: {
      imports = [ (wrapHmModule inputs.stylix.homeModules.stylix) ];
    })
  ];
};
```

### Mixing native and HM options

Native hjem options and HM-translated options coexist in the same user block:

```nix
eigenhome.users.alice = {
  enable = true;
  imports = [ eigenhome.homeModules.hm-compat ];

  # Native hjem
  files.".local/bin/backup" = {
    source = ./scripts/backup.sh;
    executable = true;
  };
  xdg.config.files."myapp/config.toml".text = ''
    key = "value"
  '';

  # HM modules
  programs.git = {
    enable = true;
    userName = "Alice";
    userEmail = "alice@example.com";
  };
  programs.firefox.enable = true;
  programs.yazi.enable = true;
};
```

### How `wrapHmModule` works

Importing `hm-compat` is all you need — the supported `programs.*` options work immediately with no additional setup. The rest of this section explains the mechanism for anyone who wants to understand how, or who needs to wrap additional HM modules manually.

Home Manager modules expect `lib.hm.*` helpers (e.g., `lib.hm.dag.entryAfter`, `lib.hm.shell.mkBashIntegrationOption`). The NixOS module system hardwires `lib` at evaluation time — `_module.args` cannot override it. `wrapHmModule` solves this by intercepting module function calls and injecting an extended `lib` that includes `lib.hm`:

```nix
# wrap-hm-module.nix — simplified
wrapImport = mod:
  if isPath mod then
    args: wrapImport ((import mod) (args // { lib = hmExtLib; }))
  else if isFunction mod then
    args: wrapImport (mod (args // { lib = hmExtLib; }))
  else if isAttrs mod && mod ? imports then
    mod // { imports = map wrapImport mod.imports; }
  else
    mod;
```

The wrapper is recursive: multi-file HM modules (like firefox) use `imports` to pull in sub-modules, and each sub-module also receives the extended `lib`. Path inputs produce stable `key` attributes for deduplication, so importing the same HM module from multiple sources doesn't cause conflicts.

The compatibility layer ([`programs-stubs.nix`](modules/hm-compat/programs-stubs.nix)) maintains a curated list of programs and resolves each to its upstream HM module path. Programs with upstream modules are bulk-imported via `wrapHmModule`; programs without one (nixcord, nixvim, spicetify, etc.) receive freeform submodule stubs instead, so meta-modules like Stylix can write to `programs.X.*` without errors.

Shell integrations ([`shell-stubs.nix`](modules/hm-compat/shell-stubs.nix)) and VCS diff tools ([`cross-module-stubs.nix`](modules/hm-compat/cross-module-stubs.nix)) are handled separately with typed option declarations, since they require cross-module coordination (e.g., routing starship's init snippet into rum's shell config).

#### Supported `programs.*`

Programs with upstream HM modules are imported via `wrapHmModule`. Programs declared with typed options elsewhere are marked with their source.

| Category | Programs |
|----------|----------|
| **Shells** | bash\*, fish\*, ion\*, nushell\*, zsh\* |
| **Version control** | git, gitui, jjui, lazygit, gpg\*\*, delta\*\*, diff-highlight\*\*, diff-so-fancy\*\*, difftastic\*\*, patdiff\*\*, riff\*\* |
| **Browsers** | chromium, floorp, librewolf, qutebrowser, zen-browser, firefox\*\*\* |
| **Editors** | emacs, helix, micro, neovide, neovim, nixvim†, nvf†, opencode, vim, vscode, zed-editor |
| **Terminals** | alacritty, foot, ghostty, kitty, rio, tmux, wezterm, zellij |
| **Launchers** | bemenu, fuzzel, rofi, tofi, wofi |
| **Desktop** | dconf, hyprland, hyprlock, hyprpanel, i3bar-river, regreet, swaylock, waybar, wayprompt |
| **CLI** | bat, broot, btop, direnv, fzf, k9s, kubecolor, mangohud, starship, vivid, yazi |
| **Media** | cava, cavalier, mpv, ncspot, nixcord†, sioyek, spicetify†, spotify-player, vesktop |
| **Other** | anki, ashell, dank-material-shell, foliate, halloy, noctalia-shell, obsidian, vicinae, zathura |

\* `shell-stubs.nix` — typed options with rum shell integration
\*\* `cross-module-stubs.nix` — typed options for cross-module VCS pager wiring
\*\*\* Provided by external flake (e.g., [`firefox-config`](https://github.com/starbaser/firefox-config))
† Freeform stub (no upstream HM module)

Additional HM options supported: `home.file`, `home.packages`, `home.sessionVariables`, `home.activation`, `xdg.configFile`, `xdg.dataFile`, `systemd.user.services`, `systemd.user.timers`.

## Rum Integration

[Rum](https://github.com/snugnug/hjem-rum) modules work alongside eigenhome via the `hjem-lib` shim. Import rum into user configs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    eigenhome.url = "github:starbaser/eigenhome";
    rum = {
      url = "github:snugnug/hjem-rum";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hjem.inputs.smfh.follows = "eigenhome/smfh";
    };
  };

  outputs = { nixpkgs, eigenhome, rum, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        eigenhome.nixosModules.default

        {
          eigenhome.users.alice = {
            enable = true;
            imports = [
              eigenhome.homeModules.hm-compat
              rum.hjemModules.default
            ];

            # Rum native shell
            rum.programs.zsh.enable = true;

            # HM program — integrates with rum's zsh automatically
            programs.starship.enable = true;
          };
        }
      ];
    };
  };
}
```

When rum's shell modules are active, HM shell integrations (like starship's init) are routed into the rum-managed shell config instead of generating standalone compatibility scripts.

## Reference

### Top-level options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `eigenhome.users.<name>` | submodule | `{}` | Per-user configuration |
| `eigenhome.extraModules` | `listOf raw` | `[]` | Modules loaded into every user submodule |
| `eigenhome.specialArgs` | `attrs` | `{}` | Additional specialArgs passed to user modules |
| `eigenhome.linker` | `package \| null` | `smfh` | File linker package; `null` for systemd-tmpfiles fallback |
| `eigenhome.linkerOptions` | `listOf str \| attrs` | `[]` | Additional arguments passed to the linker |
| `eigenhome.clobberByDefault` | `bool` | `false` | Global default clobber behavior |

### Per-user options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `bool` | `false` | Enable this user's config |
| `files.<path>.*` | file entry | — | Files deployed to `$HOME` |
| `xdg.config.files.<path>.*` | file entry | — | Files deployed to `$XDG_CONFIG_HOME` |
| `xdg.data.files.<path>.*` | file entry | — | Files deployed to `$XDG_DATA_HOME` |
| `xdg.cache.files.<path>.*` | file entry | — | Files deployed to `$XDG_CACHE_HOME` |
| `xdg.state.files.<path>.*` | file entry | — | Files deployed to `$XDG_STATE_HOME` |
| `packages` | `listOf package` | `[]` | Packages added to the user's profile |
| `environment.sessionVariables` | `attrsOf (null \| int \| str \| path \| listOf ...)` | `{}` | Environment variables exported at session start |
| `clobberFiles` | `bool` | inherited | Per-user clobber override (inherits from `clobberByDefault`) |

### File entry options

Each file entry under `files.*` or `xdg.*.files.*` accepts:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `bool` | `true` | Whether to create this file |
| `type` | `enum` | `"symlink"` | Operation type: `symlink`, `copy`, `delete`, `directory`, `modify` |
| `target` | `str` | attr name | Relative path to the target file |
| `text` | `nullOr lines` | `null` | Inline text content (derives `source` automatically) |
| `source` | `nullOr path` | `null` | Path to source file or directory |
| `executable` | `bool` | `false` | Set the execute bit on the target |
| `clobber` | `bool` | inherited | Per-file clobber override |
| `recursive` | `bool` | `false` | Expand directory source into individual symlinks |
| `onChange` | `lines` | `""` | Shell commands to run after linking |
| `permissions` | `nullOr str` | `null` | Octal permissions (non-symlink types only) |
| `uid` | `nullOr str` | `null` | Owner user ID (non-symlink types only) |
| `gid` | `nullOr str` | `null` | Owner group ID (non-symlink types only) |

### Clobber precedence

Clobber controls whether existing files at the target path are overwritten:

```
eigenhome.clobberByDefault    (global)
  └─▶ eigenhome.users.<name>.clobberFiles    (per-user override)
        └─▶ files.<path>.clobber    (per-file override)
```

Each level overrides the one above via `mkDefault` priority.

### Hjem migration

If you're migrating from [hjem](https://github.com/feel-co/hjem), import the namespace alias module:

```nix
modules = [
  eigenhome.nixosModules.default
  eigenhome.nixosModules.hjem-compat  # hjem.* → eigenhome.*
];
```

This maps `hjem.users`, `hjem.clobberByDefault`, etc. to their `eigenhome.*` equivalents via `mkRenamedOptionModule`, so existing hjem configs work without changes.

eigenhome removes hjem's `generator`/`value` indirection. If you use it, the rewrite is mechanical:

```nix
# hjem — generator/value dispatches to source or text automatically
xdg.config.files."foo/settings.json" = {
  generator = lib.generators.toJSON { };
  value = {
    theme = "dark";
    fontSize = 14;
  };
};

# eigenhome — assign source or text directly
xdg.config.files."foo/settings.json".source =
  (pkgs.formats.json { }).generate "settings.json" {
    theme = "dark";
    fontSize = 14;
  };

# or, if you just need a string (no store path):
xdg.config.files."foo/settings.json".text = builtins.toJSON {
  theme = "dark";
  fontSize = 14;
};
```

The same pattern applies to other formats: `lib.generators.toTOML {}` → `text = lib.generators.toTOML {} data;`, `lib.generators.toINI {}` → `text = lib.generators.toINI {} data;`.

## Testing

```bash
nix flake check                                    # all 14 tests
nix build .#checks.x86_64-linux.basic              # single test
```

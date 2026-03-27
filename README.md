# `eigenhome` - `$HOME` is the eigenvector.

Declarative home directory management for NixOS. `eigenhome` unifies the vast catalog of 1000+ [Home Manager](https://github.com/nix-community/home-manager) modules with the streamlined interface of [hjem](https://github.com/feel-co/hjem). One config, no transformation.

## Installation

Add eigenhome to your NixOS flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    eigenhome.url = "github:starbaser/eigenhome";
  };

  outputs = { nixpkgs, eigenhome, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        eigenhome.nixosModules.default

        ({ pkgs, ... }: {
          eigenhome.users.alice = {
            enable = true;
            files.".config/hello.txt".text = "Hello, eigenhome.";
            packages = [ pkgs.htop pkgs.ripgrep ];
          };
        })
      ];
    };
  };
}
```

### Flake Outputs

| Output | Purpose |
|--------|---------|
| `nixosModules.default` | Core eigenhome + activation (recommended) |
| `nixosModules.eigenhome` | Core module only |
| `nixosModules.hjem-lib` | Lib shim so rum modules resolve `hjem-lib` to eigenhome |
| `nixosModules.activation` | Activation service standalone |
| `nixosModules.hjem-compat` | Hjem namespace aliases (`hjem.*` → `eigenhome.*`) |
| `homeModules.hm-compat` | Home Manager compatibility layer |
| `homeModules.default` | Same as `hm-compat` |
| `nixOnDroidModules.default` | Nix-on-Droid support |
| `packages.<system>.smfh` | The smfh file linker |

## Quick Start

### Deploy files

```nix
eigenhome.users.alice = {
  enable = true;

  # Inline text
  files.".config/app/config.toml".text = ''
    [settings]
    theme = "dark"
  '';

  # From a source path
  files.".local/bin/myscript" = {
    source = ./scripts/myscript.sh;
    executable = true;
  };

  # Recursive directory expansion
  files.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # User packages
  packages = [ pkgs.git pkgs.htop ];

  # Environment variables
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

Changing `xdg.config.directory` (and the others) automatically exports the corresponding `XDG_*_HOME` variable.

## Home Manager Compatibility

eigenhome can evaluate standard Home Manager modules without Home Manager itself. Import the compatibility layer into user configs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    eigenhome.url = "github:starbaser/eigenhome";
  };

  outputs = { nixpkgs, eigenhome, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        eigenhome.nixosModules.default

        {
          eigenhome.users.alice = {
            enable = true;
            imports = [ eigenhome.homeModules.hm-compat ];

            programs.git = {
              enable = true;
              userName = "Alice";
              userEmail = "alice@example.com";
              aliases = { co = "checkout"; st = "status"; };
              ignores = [ "*.swp" ".direnv" ];
            };

            programs.starship.enable = true;
            programs.direnv.enable = true;
          };
        }
      ];
    };
  };
}
```

To load the compatibility layer for **all** users, use `extraModules`:

```nix
eigenhome.extraModules = [ eigenhome.homeModules.hm-compat ];
```

### Mixing native and HM options

Native eigenhome options and HM-translated options coexist in the same user block:

```nix
eigenhome.users.alice = {
  enable = true;
  imports = [ eigenhome.homeModules.hm-compat ];

  # Native eigenhome
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

### Supported HM programs

The compatibility layer supports upstream HM modules for these `programs.*` options:

**Shells:** bash, fish, ion, nushell, zsh
**Version control:** delta, diff-highlight, diff-so-fancy, difftastic, git, gitui, gpg, jjui, lazygit, patdiff, riff
**Browsers:** chromium, firefox, floorp, librewolf, qutebrowser, zen-browser
**Editors:** emacs, helix, micro, neovide, neovim, nixvim, nvf, opencode, vim, vscode, zed-editor
**Terminals:** alacritty, foot, ghostty, kitty, rio, tmux, wezterm, zellij
**Launchers:** bemenu, fuzzel, rofi, tofi, wofi
**Desktop:** dconf, hyprland, hyprlock, hyprpanel, i3bar-river, regreet, swaylock, waybar, wayprompt
**CLI:** bat, broot, btop, fzf, k9s, kubecolor, mangohud, starship, vivid, yazi
**Media:** cava, cavalier, mpv, ncspot, nixcord, sioyek, spicetify, spotify-player, vesktop
**Other:** anki, ashell, dank-material-shell, direnv, foliate, halloy, noctalia-shell, obsidian, vicinae, zathura

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
| `environment.sessionVariables` | `attrsOf str` | `{}` | Environment variables exported at session start |
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

> eigenhome removes hjem's `generator`/`value` indirection. If your hjem config used `generator = lib.generators.toJSON {}; value = { ... };`, rewrite to `source = (pkgs.formats.json {}).generate "name" data;` or `text = builtins.toJSON data;`.

## Testing

```bash
nix flake check                                    # all 14 tests
nix build .#checks.x86_64-linux.basic              # single test
```

**Core tests:** `basic`, `linker`, `xdg`, `xdg-linker`, `special-args`, `no-users-linker`
**HM-compat tests:** `starship`, `starship-rum`, `git`, `direnv`, `firefox`, `yazi`, `activation`, `systemd-bridge`

## License

MIT

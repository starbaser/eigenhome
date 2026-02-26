# hjem-compat

**Home Manager module compatibility shim for hjem**

## The Problem

Hjem provides a clean, minimal file-linking backend for `$HOME`. Hjem-rum
adds ~40 native modules. But Home Manager has **200+ program modules** that
users depend on daily — starship, git, direnv, firefox, neovim, tmux, and
the entire long tail.

Users migrating to hjem face a choice: rewrite configs manually, wait for
rum ports, or stay on Home Manager. None of these are satisfying.

## The Solution

`hjem-compat` is a standalone flake that translates Home Manager's option
interface into hjem primitives. Users import unmodified HM program modules
and configure them normally — hjem-compat handles the rest.

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                      User Configuration                          │
  │                                                                  │
  │   hjem.users.alice = {                                           │
  │     imports = [                                                  │
  │       hjemCompatModule                                           │
  │       (wrapHmModule "${hm}/modules/programs/starship.nix")       │
  │     ];                                                           │
  │                                                                  │
  │     programs.starship = {        # Standard HM option!           │
  │       enable = true;                                             │
  │       settings.add_newline = false;                              │
  │     };                                                           │
  │                                                                  │
  │     rum.programs.kitty.enable = true;   # Native rum, coexists   │
  │   };                                                             │
  └──────────────────────────────────────────────────────────────────┘
```

**Zero changes to hjem or hjem-rum required.** Injects via `hjem.extraModules`.

## Architecture

```
  ┌──────────────────┐
  │  HM Module       │  Unmodified programs/starship.nix, programs/git.nix, ...
  │  (unchanged)     │
  └────────┬─────────┘
           │ wrapHmModule injects lib.hm
           ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                     hjem-compat shim                         │
  │                                                              │
  │  ┌───────────────┐  ┌────────────────┐  ┌────────────────┐   │
  │  │  lib.hm       │  │ home.* stubs   │  │  xdg.* stubs   │   │
  │  │  injection    │  │ (file,packages │  │  (configFile,  │   │
  │  │  via hmExtLib │  │  sessionVars)  │  │   dataFile)    │   │
  │  └──────┬────────┘  └──────┬─────────┘  └───────┬────────┘   │
  │         │                  │                    │            │
  │         ▼                  ▼                    ▼            │
  │  ┌──────────────────────────────────────────────────────┐    │
  │  │               translation.nix                        │    │
  │  │                                                      │    │
  │  │  home.file."path"      ──▶  files."path"             │    │
  │  │  xdg.configFile."p"   ──▶  xdg.config.files."p"      │    │
  │  │  xdg.dataFile."p"     ──▶  xdg.data.files."p"        │    │
  │  │  home.packages         ──▶  packages                 │    │
  │  │  home.sessionVariables ──▶  environment.sessionVars  │    │
  │  └──────────────────────────────────────────────────────┘    │
  │                        │                                     │
  │  ┌──────────────────────────────────────────────────────┐    │
  │  │               shell-bridge.nix                       │    │
  │  │                                                      │    │
  │  │    HM shell writes                                   │    │
  │  │         │                                            │    │
  │  │    ┌────┴────┐                                       │    │
  │  │    ▼         ▼                                       │    │
  │  │  ┌───────┐ ┌──────────┐                              │    │
  │  │  │  Rum  │ │Standalone│                              │    │
  │  │  │ bridge│ │ fallback │                              │    │
  │  │  └───┬───┘ └────┬─────┘                              │    │
  │  │      ▼          ▼                                    │    │
  │  │  rum.programs  xdg.config.files                      │    │
  │  │  .zsh/fish/    "zsh/hm-compat.zsh"                   │    │
  │  │  nushell       "bash/hm-compat.sh"                   │    │
  │  │  (via mkAfter) "fish/conf.d/hm-compat.fish"          │    │
  │  └──────────────────────────────────────────────────────┘    │
  └──────────────────────────────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │     hjem manifest      │
            │   (smfh / tmpfiles)    │
            │                        │
            │   symlinks in $HOME    │
            └────────────────────────┘
```

## Key Design Decisions

### 1. The `lib.hm` Problem

Every HM module uses `lib.hm.dag.*`, `lib.hm.shell.*`, `lib.hm.types.*`.
The Nix module system **hardwires `lib`** in `evalModules` — it cannot be
overridden via `_module.args.lib`.

**Solution**: `wrapHmModule` intercepts the module function and injects a
composite `hmExtLib` (`pkgs.lib` extended with `lib.hm`) directly:

```
  ┌────────────────────┐     ┌───────────────────────────┐
  │   HM Module        │     │   wrapHmModule            │
  │                    │     │                           │
  │   { lib, config,   │────▶│   Intercepts function     │
  │     pkgs, ... }:   │     │   Overrides: lib=hmExtLib │
  │                    │     │                           │
  └────────────────────┘     └───────────────────────────┘
```

`lib.hm` itself is pure — `{ lib }: rec { ... }` — safe to import directly.

### 2. Dual-Mode Shell Bridge

```
  ┌──────────────────────────────────────────┐
  │   HM Module writes:                      │
  │   programs.zsh.initContent = "..."       │
  │   programs.fish.shellInit  = "..."       │
  └─────────────────────┬────────────────────┘
                        │
               ┌────────┴────────┐
               ▼                 ▼
  ┌───────────────────┐  ┌────────────────────┐
  │   Rum Detected    │  │   No Rum           │
  │                   │  │                    │
  │  options ? rum    │  │  Standalone files  │
  │       = true      │  │  in XDG config     │
  │                   │  │                    │
  │  rum.programs.    │  │  zsh/hm-compat.zsh │
  │  zsh.initConfig   │  │  (user sources     │
  │  (via mkAfter)    │  │   in .zshrc)       │
  └───────────────────┘  └────────────────────┘
```

When rum is present, shell init lines merge naturally into rum's managed
config. When rum is absent, sourceable fragments are written to XDG config
directories.

Fish's `conf.d/` auto-sourcing means zero user action for fish.

### 3. Translation Safety

```
  HM file entry                    Hjem file entry
  ┌───────────────────┐             ┌───────────────────┐
  │ target: relative  │────────────▶│ key: target       │
  │ source: derivation│────────────▶│ source: derivation│
  │ executable: null  │──coerce────▶│ executable: false │
  │ force: true       │──rename────▶│ clobber: true     │
  │ text: "..."       │──skip──────▶│ (not passed)      │
  └───────────────────┘             └───────────────────┘
```

- HM's `target` (already relativized) becomes the hjem attrset key
- Only `source` is passed — avoids dual derivation conflicts
- `executable` coerced from `nullOr bool` to `bool`
- `text` is never forwarded (HM already resolved it into `source`)

## Module Compatibility Tiers

```
  Tier 1: Config-only ─────────────────── ✅ Fully supported
  │ starship, alacritty, kitty, foot, helix, yazi, bottom,
  │ tealdeer, fastfetch, lsd, ghostty, neovide, broot
  │
  Tier 2: Config + Shell init ─────────── ✅ Fully supported
  │ git, direnv, zoxide, fzf, nix-your-shell, starship
  │ (shell hooks route through bridge)
  │
  Tier 3: Config + Activation ─────────── ⚠  Partial (stubs)
  │ firefox, thunderbird, dconf, font management
  │ (activation DAG collected but not executed)
  │
  Tier 4: Config + Services ───────────── ⚠  Partial (stubs)
  │ syncthing, mako, dunst, gpg-agent, ssh-agent
  │ (systemd options stubbed, no functional bridge)
```

**Tier 1+2 covers the vast majority of user demand.** These are the
modules people use daily and ask about in hjem discussions.

## What This Is Not

- **Not a fork of Home Manager.** HM modules are imported unmodified.
- **Not a replacement for hjem-rum.** Native rum modules are preferred;
  compat fills the gaps for the long tail.
- **Not heavyweight.** ~11 module files. Only evaluates what you import.
  Zero overhead if no HM modules are used.
- **Not coupled to hjem internals.** Uses `hjem.extraModules`, the public
  extension point. No patches, no forks.

## Coexistence with Rum

Native rum modules and HM compat modules coexist cleanly:

```
  hjem.users.alice = {
    imports = [ hjemRumModule hjemCompatModule ... ];

    # Native rum — full control, preferred
    rum.programs.kitty.enable = true;
    rum.programs.zsh.enable = true;

    # HM compat — for modules rum doesn't have yet
    programs.starship.enable = true;    # via wrapHmModule
    programs.direnv.enable = true;      # via wrapHmModule
  };
```

If both rum and HM try to manage the same program, `warnings.nix` emits
a clear diagnostic:

```
  warning: programs.starship is configured via both hjem-rum and
  hjem-compat. The rum module takes precedence. Remove one to
  avoid conflicts.
```

## File Structure

```
  hjem-compat/
  ├── flake.nix                    Inputs: nixpkgs, hjem, hjem-rum, home-manager
  ├── modules/
  │   ├── default.nix              Entry point (imports all below)
  │   ├── lib-hm.nix              lib.hm injection + wrapHmModule
  │   ├── wrap-hm-module.nix      HM module wrapper function
  │   ├── home-options.nix        home.file, packages, sessionVariables, ...
  │   ├── xdg-options.nix         xdg.configFile, dataFile, cacheFile, ...
  │   ├── config-lib.nix          config.lib.file.mkOutOfStoreSymlink, ...
  │   ├── translation.nix         HM options to hjem primitives mapping
  │   ├── shell-stubs.nix         programs.bash/zsh/fish/nushell option sinks
  │   ├── shell-bridge.nix        Dual-mode rum/standalone routing
  │   ├── cross-module-stubs.nix  meta, accounts.email, systemd.user stubs
  │   └── warnings.nix            Unsupported feature + conflict detection
  └── tests/
      ├── default.nix              Test harness
      ├── basic-files.nix          File translation validation
      ├── starship.nix             Config + shell init + session variable
      ├── starship-rum.nix         Rum bridge routing verification
      ├── git.nix                  gitIni config + XDG files
      └── direnv.nix               Config + shell hooks
```

## Roadmap

**Phase 1** (current): Core shim + shell bridge. Tier 1+2 modules.
**Phase 2**: Activation DAG runner for Tier 3 (firefox, dconf).
**Phase 3**: systemd.user service bridge for Tier 4 (syncthing, mako).

## Questions for Maintainers

1. Does the shim approach align with hjem's philosophy?
2. Should `wrapHmModule` live in hjem's lib eventually?
3. Interest in integrating the shell bridge detection into rum directly?
4. Preferred home for this project — feel-co org, separate, or community?

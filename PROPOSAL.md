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

```text
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

```text
                  ┌────────────────────────────────────────────────────────┐
                  │                  NixOS Configuration                   │
                  │                                                        │
                  │     imports = [ hjem-compat.nixosModules.default ];    │
                  │     hjem.extraModules = [ ...hjemModules.default ];    │
                  └───────────────────────────┬────────────────────────────┘
                                              │
                        ┌─────────────────────┴──────────────────────┐
                        ▼                                            ▼
           ┌───────────────────────────────────┐           ┌───────────────────┐
           │            hjemModule             │           │    nixosModule    │
           │         (hjem submodule)          │           │   (NixOS level)   │
           │                                   │ script    │                   │
           │  ┌───────────────┐ ┌──────────────┤  path     │ ┌───────────────┐ │
           │  │systemd-bridge │ │ activation-  ├──────────▶│ │hjem-compat-   │ │
           │  │               │ │ runner.nix   │           │ │activate@.svc  │ │
           │  │ systemd.user  │ └──────────────┘           │ └───────────────┘ │
           │  │ INI sections  │                │           │                   │
           │  │       ▼       │ ┌──────────────┐           │   daemon-reload   │
           │  │ systemd.units │ │ shell-bridge │           │   triggers new    │
           │  └───────────────┘ │              │           │   unit pickup     │
           │                    │ HM shell ──┐ │           │                   │
           │  ┌───────────────┐ │   rum? ────┤ │           └───────────────────┘
           │  │translation.nix│ │   no rum ──┘ │
           │  │               │ └──────────────┘
           │  │ home.file     │                │
           │  │   ▼ files     │                │
           │  │ xdg.*File     │                │
           │  └───────────────┘                │
           └──────────────────┬────────────────┘
                              │
                              ▼
           ┌───────────────────────────────────┐
           │           hjem manifest           │
           │         (smfh / tmpfiles)         │
           │         symlinks in $HOME         │
           └───────────────────────────────────┘
```

## Key Design Decisions

### 1. The `lib.hm` Problem

Every HM module uses `lib.hm.dag.*`, `lib.hm.shell.*`, `lib.hm.types.*`.
The Nix module system **hardwires `lib`** in `evalModules` — it cannot be
overridden via `_module.args.lib`.

**Solution**: `wrapHmModule` intercepts the module function and injects a
composite `hmExtLib` (`pkgs.lib` extended with `lib.hm`) directly:

```text
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

```text
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

```text
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

### 4. Activation DAG Runner

Some HM modules require imperative actions beyond file linking. Firefox
copies profile directory structures and writes `profiles.ini`. Dconf
runs `dconf load` to push settings into the GNOME database. GPG imports
keys and sets directory permissions. Font management runs `fc-cache`
after linking font files.

These modules express this work as `home.activation` entries — a DAG
(directed acyclic graph) of named shell script fragments with explicit
ordering dependencies (`entryAfter`, `entryBefore`). Hjem has no
equivalent concept: it is purely a file linker with a systemd oneshot
service. The activation DAG runner bridges this gap.

**How it works**: At evaluation time, the runner topo-sorts all
`home.activation` entries using HM's own `lib.hm.dag.topoSort`, then
filters out HM's 8 built-in lifecycle phases that conflict with hjem's
linker model (hjem handles file linking and package installation
natively — these phases would duplicate or break that work). The
remaining entries are compiled into an executable bash script with
minimal HM-compatible shell helpers (`run`, `verboseEcho`, `_iNote`).

The script is written to `~/.local/share/hjem-compat/activate` via
hjem's file linker, and a NixOS-level systemd service executes it after
file linking completes:

```text
  hjem.target
    └─▶ hjem-activate@alice.service        (smfh links files)
         └─▶ hjem-compat-activate@alice.service
               ├─ systemctl --user daemon-reload  (picks up new units)
               └─ ~/.local/share/hjem-compat/activate
                    ├─ createTestDir    ◀── user/program entries
                    ├─ setupGpgHome         (topo-sorted, filtered)
                    └─ rebuildFontCache
```

```text
  Filtered HM built-in phases (handled natively by hjem):
    writeBoundary, installPackages, checkLinkTargets,
    linkGeneration, checkFilesChanged, onFilesChange,
    createXdgUserDirectories, reloadSystemd
```

**Without this runner**, Tier 3 modules would silently produce broken
results — config files linked correctly, but imperative setup steps
skipped. Firefox would lack a usable profile, dconf settings wouldn't
load, font caches would be stale.

### 5. Systemd Bridge

HM modules define systemd units using INI-section format:
```nix
systemd.user.services.foo = {
  Unit.Description = "...";
  Service.ExecStart = "...";
  Install.WantedBy = ["default.target"];
};
```

Hjem's native `systemd.services` uses NixOS types (different schema).
Rather than converting between these incompatible schemas, the bridge
generates INI text directly and injects into hjem's internal
`systemd.units` option — the same data store that hjem's own unit
generation feeds into.

```text
  HM INI sections ──▶ toSystemdIni ──▶ systemd.units.text
  Install.WantedBy ──▶ unit.wantedBy (symlink generation)
```

## Module Compatibility Tiers

```text
  Tier 1: Config-only ─────────────────── ✅ Fully supported
  │ starship, alacritty, kitty, foot, helix, yazi, bottom,
  │ tealdeer, fastfetch, lsd, ghostty, neovide, broot
  │
  Tier 2: Config + Shell init ─────────── ✅ Fully supported
  │ git, direnv, zoxide, fzf, nix-your-shell, starship
  │ (shell hooks route through bridge)
  │
  Tier 3: Config + Activation ─────────── ✅ Fully supported
  │ firefox, thunderbird, dconf, font management
  │ (activation DAG sorted, filtered, executed post-linking)
  │
  Tier 4: Config + Services ───────────── ✅ Fully supported
  │ syncthing, mako, dunst, gpg-agent, ssh-agent
  │ (systemd units bridged via INI → hjem systemd.units)
```

**All four tiers are covered.** Tier 1+2 covers the vast majority of
daily-use modules. Tier 3+4 enables the full HM ecosystem.

## What This Is Not

- **Not a fork of Home Manager.** HM modules are imported unmodified.
- **Not a replacement for hjem-rum.** Native rum modules are preferred;
  compat fills the gaps for the long tail.
- **Not heavyweight.** ~13 module files. Only evaluates what you import.
  Zero overhead if no HM modules are used.
- **Not coupled to hjem internals.** Uses `hjem.extraModules`, the public
  extension point. No patches, no forks.

## Coexistence with Rum

Native rum modules and HM compat modules coexist cleanly:

```nix
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

```text
  warning: programs.starship is configured via both hjem-rum and
  hjem-compat. The rum module takes precedence. Remove one to
  avoid conflicts.
```

## File Structure

```text
  hjem-compat/
  ├── flake.nix                    Inputs: nixpkgs, hjem, hjem-rum, home-manager
  │                                Outputs: hjemModules, nixosModules, checks
  ├── nixos/
  │   └── activation.nix           NixOS-level activation service
  ├── modules/
  │   ├── default.nix              Entry point (imports all below)
  │   ├── lib-hm.nix              lib.hm injection + wrapHmModule
  │   ├── wrap-hm-module.nix      HM module wrapper function
  │   ├── home-options.nix        home.file, packages, sessionVariables, activation
  │   ├── xdg-options.nix         xdg.configFile, dataFile, cacheFile, ...
  │   ├── config-lib.nix          config.lib.file.mkOutOfStoreSymlink, ...
  │   ├── translation.nix         HM options to hjem primitives mapping
  │   ├── shell-stubs.nix         programs.bash/zsh/fish/nushell option sinks
  │   ├── shell-bridge.nix        Dual-mode rum/standalone routing
  │   ├── activation-runner.nix   DAG → bash script → hjem files
  │   ├── systemd-bridge.nix      systemd.user INI → hjem systemd.units
  │   ├── cross-module-stubs.nix  meta, accounts.email, launchd stubs
  │   └── warnings.nix            Unsupported feature + conflict detection
  └── tests/
      ├── default.nix              Test harness
      ├── basic-files.nix          File translation validation
      ├── starship.nix             Config + shell init + session variable
      ├── starship-rum.nix         Rum bridge routing verification
      ├── git.nix                  gitIni config + XDG files
      ├── direnv.nix               Config + shell hooks
      ├── activation.nix           Activation DAG runner
      └── systemd-bridge.nix       Systemd unit bridge
```

## Not Yet Implemented

- `accounts.email` bridge — HM's email account options are not yet translated.
- Extended activation hooks — custom pre/post-activation hook points.

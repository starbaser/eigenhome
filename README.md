# hjem-compat

Home Manager module compatibility shim for [hjem](https://github.com/feel-co/hjem).

Import unmodified Home Manager program modules into hjem and configure
them normally — hjem-compat translates HM's option interface into hjem
primitives. Zero changes to hjem or hjem-rum required.

## Installation

Add hjem-compat to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem-compat = {
      url = "github:starbaser/hjem-compat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hjem.follows = "hjem";
      inputs.home-manager.follows = "home-manager";
    };
  };
}
```

Import the NixOS module and inject the hjem module:

```nix
# In your NixOS configuration
{ inputs, ... }: {
  imports = [
    inputs.hjem-compat.nixosModules.default   # activation service
  ];

  hjem.extraModules = [
    inputs.hjem-compat.hjemModules.default    # compatibility shim
  ];
}
```

## Usage

Inside a hjem user block, import wrapped HM modules with `wrapHmModule`
and configure them using their standard HM options:

```nix
hjem.users.alice = { wrapHmModule, ... }: {
  imports = [
    (wrapHmModule "${inputs.home-manager}/modules/programs/starship.nix")
    (wrapHmModule "${inputs.home-manager}/modules/programs/direnv.nix")
  ];

  # Standard HM options — works as documented
  programs.starship = {
    enable = true;
    settings.add_newline = false;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
};
```

`wrapHmModule` is a module argument provided by hjem-compat. It injects
`lib.hm` into the HM module so it evaluates correctly within hjem's
module system.

### Coexistence with hjem-rum

Native rum modules and HM compat modules coexist cleanly in the same
user block:

```nix
hjem.users.alice = { wrapHmModule, ... }: {
  imports = [
    (wrapHmModule "${inputs.home-manager}/modules/programs/starship.nix")
  ];

  # Native rum — full control, preferred
  rum.programs.kitty.enable = true;
  rum.programs.zsh.enable = true;

  # HM compat — for modules rum doesn't have yet
  programs.starship.enable = true;
};
```

When rum is detected, shell init lines from HM modules route into rum's
managed config. When rum is absent, sourceable fragments are written to
XDG config directories.

### Systemd user services

HM modules that define systemd units work automatically:

```nix
hjem.users.alice = { wrapHmModule, ... }: {
  imports = [
    (wrapHmModule "${inputs.home-manager}/modules/services/syncthing.nix")
  ];

  services.syncthing.enable = true;
};
```

Unit files are generated and placed in
`~/.config/systemd/user/` via hjem's native systemd support.

### Activation scripts

HM modules that require imperative setup (firefox profile creation,
dconf loading, gpg key import) are supported through the activation DAG
runner. The `nixosModules.default` import is required for these — it
provides a systemd service that executes activation scripts after hjem
links files.

## What gets translated

| HM option | hjem equivalent |
|---|---|
| `home.file.*` | `files.*` |
| `home.packages` | `packages` |
| `home.sessionVariables` | `environment.sessionVariables` |
| `xdg.configFile.*` | `xdg.config.files.*` |
| `xdg.dataFile.*` | `xdg.data.files.*` |
| `xdg.cacheFile.*` | `xdg.cache.files.*` |
| `xdg.stateFile.*` | `xdg.state.files.*` |
| `programs.{bash,zsh,fish}.*` | rum bridge or XDG config files |
| `systemd.user.{services,timers,...}` | `systemd.units` (INI text) |
| `home.activation.*` | activation script at `~/.local/share/hjem-compat/activate` |

## Module compatibility tiers

| Tier | Description | Examples |
|---|---|---|
| 1 — Config only | Fully supported | starship, alacritty, kitty, foot, helix, yazi |
| 2 — Config + shell init | Fully supported | git, direnv, zoxide, fzf, starship |
| 3 — Config + activation | Fully supported | firefox, thunderbird, dconf, font management |
| 4 — Config + services | Fully supported | syncthing, mako, dunst, gpg-agent |

## Running tests

```sh
nix flake check           # all tests
nix build .#checks.x86_64-linux.starship        # individual test
nix build .#checks.x86_64-linux.activation       # activation runner
nix build .#checks.x86_64-linux.systemd-bridge   # systemd bridge
```

## Design

See [PROPOSAL.md](./PROPOSAL.md) for the full architectural design
document, including diagrams for the shell bridge, translation layer,
activation DAG runner, and systemd bridge.

## License

MPL 2.0

<!--
SPDX-FileCopyrightText: 2025 Ryan Cao <hello@ryanccn.dev>

SPDX-License-Identifier: Apache-2.0
-->

# Ferrix

Ferrix is a highly opinionated Nix flake framework for Rust projects.

It provides Rust packages with automatically populated package names and metadata, LTO and size optimization build configurations, installation of shell completion files, statically linked packages for Linux platforms, flake checks for [Clippy](https://doc.rust-lang.org/clippy/), [rustfmt](https://github.com/rust-lang/rustfmt), [nixfmt](https://github.com/NixOS/nixfmt), and [REUSE](https://reuse.software/), and a development shell out of the box with minimal configuration required.

## Getting Started

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ferrix.url = "github:ryanccn/ferrix";
  };

  outputs =
    {
      ferrix,
      ...
    }@inputs:
    ferrix.lib.mkFlake inputs {
      root = ./.;
      name = "example";
    };
}
```

## Options

- **`root` (required)**: the root of the project, required for locating important files
- `name`: the name of the project used in package attrsets and other places (_inferred from `Cargo.toml` by default_)
- `enableCompletions`: install completions by executing `<pname> completions {bash,zsh,fish}` at build time
- `enableStaticPackages`: provide static Linux packages in `legacyPackages` (_defaults to `true`_)
- `doCheck`: do checks provided by `rustPlatform` (_defaults to `false`_)
- `src`: source fileset passed to `rustPlatform.buildRustPackage` and Rust-related checks (defaults to `src`, `tests`, `Cargo.toml`, `Cargo.lock`, and `build.rs`)
- `devShells.enable`, `checks.enable`, `checks.enableNixfmt`, `checks.enableRustfmt`, `checks.enableClippy`, `checks.enableREUSE`: enable/disable devshells and specific checks in the flake (_all default to `true`_)
- `meta`, `env`, `cargoLock`: attributes that are merged with the defaults and passed to `rustPlatform.buildRustPackage` (_`meta.description` and `meta.license` inferred from `Cargo.toml` by default_)
- `packages`, `legacyPackages`: attributes that are merged with the defaults and exposed in the flake

## License

Apache-2.0

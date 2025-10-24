<!--
SPDX-FileCopyrightText: 2025 Ryan Cao <hello@ryanccn.dev>

SPDX-License-Identifier: Apache-2.0
-->

# Ferrix

Ferrix is a highly opinionated, zero-configuration Nix flake framework for Rust projects.

It provides Rust packages with automatically populated package names and metadata, LTO and size optimization build configurations, installation of shell completion files, statically linked packages for Linux platforms, flake checks for [Clippy](https://doc.rust-lang.org/clippy/), [rustfmt](https://github.com/rust-lang/rustfmt), [nixfmt](https://github.com/NixOS/nixfmt), and [REUSE](https://reuse.software/), and a development shell out of the box with no configuration required.

> [!WARNING]  
> The API surface currently can change at any time and is not guaranteed to be stable.

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
    };
}
```

## Options

- **`root` (required)**: the root of the project, required for locating important files such as `Cargo.toml` and `Cargo.lock`
- `name`: the name of the project used in package attrsets and other places (_inferred from `Cargo.toml` by default_)
- `doCheck`: do checks provided by `rustPlatform` (_defaults to `false`_)
- `enableStaticPackages`: provide static Linux packages in `legacyPackages` (_defaults to `true`_)
- `src`: source fileset passed to `rustPlatform.buildRustPackage` and Rust-related checks (defaults to `src`, `tests`, `Cargo.toml`, `Cargo.lock`, and `build.rs`)
- `completions.enable`: install completions by executing `<pname> <args> {bash,zsh,fish}` at build time
- `completions.args`: arguments passed to the project binary when installing completions
- `devShells.enable`, `checks.enable`, `checks.enableNixfmt`, `checks.enableRustfmt`, `checks.enableClippy`, `checks.enableREUSE`: enable/disable devshells and specific checks in the flake (_all default to `true`_)
- `buildInputs`, `nativeBuildInputs`, `env`, `cargoLock`, `meta`: attributes that are merged with the defaults and passed to `rustPlatform.buildRustPackage` (_`meta.description` and `meta.license` inferred from `Cargo.toml` by default_)
- `extraPostInstall`: extra `postInstall` commands that can be configured with `callPackage` arguments; configured in the shape of `{ enableDoNothing = { default = false; value = ":"; }; }`
- `systems`: systems to include in flake outputs (_defaults to `lib.systems.flakeExposed`_)
- `flake.*`: attributes that are recursively merged with the defaults and exposed in the top-level flake

## License

Apache-2.0

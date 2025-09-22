# SPDX-FileCopyrightText: 2025 Ryan Cao <hello@ryanccn.dev>
#
# SPDX-License-Identifier: Apache-2.0

{
  lib = {
    mkFlake =
      inputs:
      {
        root,
        ...
      }@options:
      let
        inherit (inputs) self nixpkgs;
        inherit (nixpkgs) lib;

        forAllSystems = lib.genAttrs lib.systems.flakeExposed;
        nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});

        cargoManifestPath = lib.path.append root "Cargo.toml";
        cargoManifest =
          if builtins.pathExists cargoManifestPath then lib.importTOML cargoManifestPath else { };
        projectName = cargoManifest.package.name or options.name;

        maybeFunction = fn: arg: if builtins.isFunction fn then fn arg else fn;

        packageFn =
          lib.setFunctionArgs
            (
              {
                lib,
                stdenv,
                rustPlatform,
                installShellFiles,
                self,
                enableLTO ? true,
                enableOptimizeSize ? false,
              }@restArgs:
              let
                year = builtins.substring 0 4 self.lastModifiedDate;
                month = builtins.substring 4 2 self.lastModifiedDate;
                day = builtins.substring 6 2 self.lastModifiedDate;
              in
              rustPlatform.buildRustPackage (finalAttrs: {
                pname = projectName;
                version = "${cargoManifest.package.version or 0}-unstable-${year}-${month}-${day}";

                src =
                  options.src or (lib.fileset.toSource {
                    inherit root;
                    fileset = lib.fileset.unions (
                      map (p: lib.fileset.maybeMissing (lib.path.append root p)) [
                        "src"
                        "tests"
                        "Cargo.toml"
                        "Cargo.lock"
                        "clippy.toml"
                        ".clippy.toml"
                        "rustfmt.toml"
                        ".rustfmt.toml"
                        cargoManifest.package.build or "build.rs"
                      ]
                    );
                  });

                cargoLock = {
                  lockFile = lib.path.append root "Cargo.lock";
                }
                // (options.cargoLock or { });

                buildInputs = options.buildInputs or [ ];

                nativeBuildInputs =
                  lib.optionals (options.completions.enable or false) [
                    installShellFiles
                  ]
                  ++ (options.nativeBuildInputs or [ ]);

                env =
                  lib.optionalAttrs enableLTO {
                    CARGO_PROFILE_RELEASE_LTO = "fat";
                    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
                  }
                  // lib.optionalAttrs enableOptimizeSize {
                    CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
                    CARGO_PROFILE_RELEASE_PANIC = "abort";
                    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
                    CARGO_PROFILE_RELEASE_STRIP = "symbols";
                  }
                  // maybeFunction (options.env or { }) finalAttrs;

                postInstall =
                  lib.optionalString
                    ((options.completions.enable or false) && (stdenv.buildPlatform.canExecute stdenv.hostPlatform))
                    ''
                      installShellCompletion --cmd ${finalAttrs.pname} \
                        --bash <("$out/bin/${finalAttrs.pname}" ${options.completions.args or "completions"} bash) \
                        --zsh <("$out/bin/${finalAttrs.pname}" ${options.completions.args or "completions"} zsh) \
                        --fish <("$out/bin/${finalAttrs.pname}" ${options.completions.args or "completions"} fish)
                    ''
                  + lib.concatStringsSep "\n\n" (
                    map (
                      pi:
                      lib.optionalString (restArgs.${pi.name} or pi.value.default) (
                        maybeFunction pi.value.value finalAttrs
                      )
                    ) (lib.attrsToList (options.extraPostInstall or { }))
                  );

                doCheck = options.doCheck or false;

                meta = {
                  inherit (cargoManifest.package) description;
                  mainProgram = finalAttrs.pname;
                }
                // (lib.optionalAttrs ((cargoManifest.package.license or null) != null) {
                  license = lib.getLicenseFromSpdxId cargoManifest.package.license;
                })
                // (options.meta or { });
              })
            )
            (
              {
                self = false;
              }
              // (lib.genAttrs (
                [
                  "lib"
                  "stdenv"
                  "rustPlatform"
                  "installShellFiles"
                  "enableLTO"
                  "enableOptimizeSize"
                ]
                ++ (builtins.attrNames (options.extraPostInstall or { }))
              ) (lib.const true))
            );
      in
      lib.recursiveUpdate (
        {
          checks = forAllSystems (
            system:
            let
              pkgs = nixpkgsFor.${system};

              mkFlakeCheck =
                args:
                pkgs.stdenv.mkDerivation (
                  {
                    name = "check-${args.name}";
                    inherit (self.packages.${system}.${projectName}) src;

                    buildPhase = ''
                      ${args.command}
                      touch "$out"
                    '';

                    doCheck = false;
                    dontInstall = true;
                    dontFixup = true;
                  }
                  // (removeAttrs args [
                    "name"
                    "command"
                  ])
                );
            in
            { }
            // lib.optionalAttrs (options.checks.enableNixfmt or options.checks.enable or true) {
              nixfmt = mkFlakeCheck {
                name = "nixfmt";
                command = "find . -name '*.nix' -exec nixfmt --check {} +";

                src = self;
                nativeBuildInputs = with pkgs; [ nixfmt-rfc-style ];
              };
            }
            // lib.optionalAttrs (options.checks.enableRustfmt or options.checks.enable or true) {
              rustfmt = mkFlakeCheck {
                name = "rustfmt";
                command = "cargo fmt --check";

                nativeBuildInputs = with pkgs; [
                  cargo
                  rustfmt
                ];
              };
            }
            // lib.optionalAttrs (options.checks.enableClippy or options.checks.enable or true) {
              clippy = mkFlakeCheck {
                name = "clippy";
                command = ''
                  cargo clippy --all-features --all-targets --tests \
                    --offline --message-format=json \
                    | clippy-sarif | tee $out | sarif-fmt
                '';

                inherit (self.packages.${system}.${projectName}) cargoDeps;
                nativeBuildInputs = with pkgs; [
                  rustPlatform.cargoSetupHook
                  cargo
                  rustc
                  clippy
                  clippy-sarif
                  sarif-fmt
                ];
              };
            }
            // lib.optionalAttrs (options.checks.enableREUSE or options.checks.enable or true) {
              reuse = mkFlakeCheck {
                name = "reuse";
                command = "reuse lint";

                src = self;
                nativeBuildInputs = with pkgs; [ reuse ];
              };
            }
          );

          devShells = forAllSystems (
            system:
            let
              pkgs = nixpkgsFor.${system};
            in
            { }
            // lib.optionalAttrs (options.devShells.enable or true) {
              default = pkgs.mkShell {
                packages = with pkgs; [
                  rustfmt
                  clippy
                  rust-analyzer
                  self.formatter.${system}
                ];

                inputsFrom = [ self.packages.${system}.${projectName} ];

                env = {
                  RUST_BACKTRACE = 1;
                  RUST_SRC_PATH = toString pkgs.rustPlatform.rustLibSrc;
                };
              };
            }
          );

          packages = forAllSystems (
            system:
            let
              pkgs = nixpkgsFor.${system};
              packages = self.overlays.default null pkgs;
            in
            {
              ${projectName} = packages.${projectName};
              default = packages.${projectName};
            }
          );

          overlays.default = _: prev: {
            ${projectName} = prev.callPackage packageFn { inherit self; };
          };

          formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-rfc-style);
        }
        // lib.optionalAttrs (options.enableStaticPackages or true) {
          legacyPackages = forAllSystems (
            system:
            nixpkgsFor.${system}.callPackage (
              {
                lib,
                pkgsCross,
                self,
              }:
              let
                crossTargets = [
                  pkgsCross.musl64.pkgsStatic
                  pkgsCross.aarch64-multiplatform.pkgsStatic
                ];
              in
              builtins.listToAttrs (
                map (
                  pkgs:
                  let
                    package = pkgs.callPackage packageFn { inherit self; };
                  in
                  lib.nameValuePair (builtins.parseDrvName package.name).name package
                ) crossTargets
              )
            ) { inherit self; }
          );
        }
      ) (options.flake or { });
  };
}

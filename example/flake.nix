# SPDX-FileCopyrightText: 2025 Ryan Cao <hello@ryanccn.dev>
#
# SPDX-License-Identifier: Apache-2.0

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ferrix.url = "path:./..";
  };

  outputs =
    {
      ferrix,
      ...
    }@inputs:
    ferrix.lib.mkFlake inputs {
      root = ./.;

      # REUSE doesn't work properly since the top level is not here;
      # it does work when not part of this example.
      checks.enableREUSE = false;
    };
}

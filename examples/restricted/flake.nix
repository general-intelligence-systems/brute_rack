{
  description = "Brute agent — restricted read-only configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    brute-nix.url = "github:general-intelligence-systems/brute_rack?dir=nix";
  };

  outputs = { self, nixpkgs, flake-utils, brute-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        brute = brute-nix.lib.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = brute.shellPackages;
          shellHook = brute.shellHook;
        };
      }
    );
}

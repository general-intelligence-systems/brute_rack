{
  description = "Brute agent — default configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    brute-nix.url = "path:../../nix";
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

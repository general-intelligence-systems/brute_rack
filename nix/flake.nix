{
  description = "Shared Nix module for Brute agent deployments — k3d, kubectl, helm, convenience scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        brute = import ./default.nix { inherit pkgs; };
      in
      {
        lib = brute;

        devShells.default = pkgs.mkShell {
          packages = brute.shellPackages;
          shellHook = brute.shellHook;
        };
      }
    );
}

{
  description = "Brute agent — default configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ruby_3_4
            bundler
            openssl
            ripgrep
            git
            bash
          ];

          shellHook = ''
            export BUNDLE_PATH=vendor/bundle
            bundle install --quiet 2>/dev/null
            echo "Brute default agent ready. Run: bundle exec async-service service.rb"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "brute-default";
          version = "0.1.0";
          src = ./.;

          buildInputs = with pkgs; [ ruby_3_4 bundler openssl ripgrep git bash ];

          installPhase = ''
            mkdir -p $out/bin $out/app
            cp -r . $out/app/
            cat > $out/bin/brute-server <<EOF
            #!/bin/sh
            cd $out/app && bundle exec async-service service.rb
            EOF
            chmod +x $out/bin/brute-server
          '';
        };
      }
    );
}

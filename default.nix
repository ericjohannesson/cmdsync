{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "cmdsync";
  version = "3";
  src = ./.;
  buildInputs = with pkgs; [
    coreutils
    bash
    findutils
    diffutils
    gnugrep
    gnused
  ];
  buildPhase = ''
    make bin/cmdsync
    make share
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp bin/cmdsync $out/bin/
    cp -r share $out/
  '';
}

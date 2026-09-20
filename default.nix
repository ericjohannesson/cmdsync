{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  pname = "cmdsync";
  version = "4";
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
    make bin
    make share
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp bin/* $out/bin/
    mkdir -p $out/share
    cp -r share/* $out/share/
  '';
}

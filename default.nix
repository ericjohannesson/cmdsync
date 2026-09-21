{ pkgs ? import (
    builtins.fetchTarball
      "https://github.com/NixOS/nixpkgs/archive/refs/tags/26.05.tar.gz"
  ) { }
}:
pkgs.stdenv.mkDerivation {
  pname = "cmdsync";
  version = "5";
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

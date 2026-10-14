{ pkgs ? import (
    builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/26.05.tar.gz";
      sha256 = "sha256-md0zn0RnwNvPyASas1yG5YUuwQ4ALA6ucL50l0DvqCo=";
    }
  ) { }
}:
pkgs.stdenv.mkDerivation {
  pname = "cmdsync";
  version = "5";
  src = ./.;
  buildInputs = with pkgs; [
    coreutils
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

{ pkgs ? import <nixpkgs> { }, ... }:
let
  build_pkgs = with pkgs; [
    coreutils
    findutils
    diffutils
    gnugrep
    gnused
  ];
  dev_pkgs = with pkgs; [
    gnupg
  ];
in
pkgs.mkShell {
  packages = build_pkgs ++ dev_pkgs;
  shellHook = ''
    export PS1="(dev-shell) $PS1"
  '';
}

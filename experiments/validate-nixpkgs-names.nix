# Checks every non-null nixpkgs attribute in lib/drivers.nix resolves.
#   nix-instantiate --eval --strict experiments/validate-nixpkgs-names.nix -A missing  # => [ ]
{ nixpkgs ? <nixpkgs> }:
let
  pkgs = import nixpkgs { config.allowUnfree = true; };
  lib = pkgs.lib;
  cat = import ../lib/drivers.nix { };
  all = lib.flatten (map lib.attrValues (lib.attrValues cat));
  named = lib.filter (p: p.nixpkgs != null) all;
in
{
  checked = builtins.length named;
  missing = map (p: p.nixpkgs) (lib.filter (p: !(lib.hasAttrByPath (lib.splitString "." p.nixpkgs) pkgs)) named);
}

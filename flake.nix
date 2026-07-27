{
  description = "nixprint — printing declared: CUPS, a chosen driver set, and discovery that actually resolves";

  # NO INPUTS. Options and a name table; `pkgs` comes from the consumer's own evaluation.

  outputs = { self }: {
    nixosModules.nixprint = ./modules/nixprint.nix;
    nixosModules.default = ./modules/nixos.nix;
    nixosModules.install = ./modules/nixos.nix;

    systemManagerModules.nixprint = ./modules/arch.nix;
    systemManagerModules.default = ./modules/arch.nix;

    lib.catalogue = import ./lib/drivers.nix { };
  };
}

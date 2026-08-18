{
  description = "nixprint — printing declared: CUPS, selected driver sets, DNS-SD discovery, and the managed queues that use them";

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

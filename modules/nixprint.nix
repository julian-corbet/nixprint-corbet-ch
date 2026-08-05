#
# nixprint — printing, declared.
#
# WHY IT IS ITS OWN MODULE. Printing is one of the last genuinely imperative corners of a
# workstation: a printer gets added once through a GUI, a driver package gets pulled in to make it
# work, and years later nobody remembers which of the three installed driver sets is the one
# actually claiming the queue. That is fine until a rebuild, and then it is not.
#
# CUPS owns the runtime files, but it is not the source of truth for a managed queue. This module
# declares the queue inputs and each backend reconciles them through CUPS' own lpadmin interface.
# A small manifest limits removal to queues that nixprint previously created; unrelated queues stay
# CUPS-owned and untouched.
{ config, lib, ... }:
let
  cfg = config.nixprint;
  cat = import ../lib/drivers.nix { };

  mkGroup = what: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${what}. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  coreSel = lib.attrValues cat.core;
  driverSel = map (k: cat.drivers.${k}) cfg.drivers;
  extraSel = map (k: cat.extras.${k}) cfg.extras;
  discoverySel = lib.optionals cfg.discovery (lib.attrValues cat.discovery);

  selected = lib.optionals cfg.enable (coreSel ++ driverSel ++ extraSel ++ discoverySel);
in
{
  options.nixprint = {
    enable = lib.mkEnableOption "printing: CUPS, declared drivers, and managed queues";

    drivers = mkGroup "printer driver sets to install" cat.drivers;
    extras = mkGroup "optional printing extras" cat.extras;

    discovery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install and enable mDNS/DNS-SD discovery for network printers through Avahi.

        This makes CUPS' dnssd:// device URIs work. Host-name resolution of .local names is a
        separate resolver concern and is intentionally not changed here.
      '';
    };

    printers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          deviceUri = lib.mkOption {
            type = lib.types.str;
            description = "CUPS device URI, as reported by lpinfo -v.";
          };

          model = lib.mkOption {
            type = lib.types.str;
            description = "CUPS model or PPD identifier, as reported by lpinfo -m.";
          };

          systemManagerModel = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              CUPS model or PPD identifier for the system-manager backend when its package layout
              differs from the NixOS driver interface. Defaults to `model`.
            '';
          };

          location = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional human-readable printer location.";
          };

          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional human-readable printer description.";
          };

          shared = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether this local CUPS queue is shared with other clients.";
          };

          ppdOptions = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "PPD options to enforce for this queue, as key-value strings.";
          };
        };
      });
      default = { };
      description = ''
        CUPS queues managed by nixprint. Attribute names are CUPS queue names. nixprint removes
        only queues recorded in its own managed-queue manifest.
      '';
    };

    defaultPrinter = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Managed CUPS queue to make the system default.";
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selected packages as pacman names, for a host's own reconciler to consume.";
    };

    retiredArchPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Exact Arch packages to remove after the selected package set is present. This is narrowly
        scoped cleanup for a reviewed migration, not a general undeclared-package prune.
      '';
    };

    driverAttrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      internal = true;
      description = "nixpkgs attribute names of the selected drivers, for services.printing.drivers.";
    };
  };

  config = {
    nixprint.archPackages = lib.unique (lib.concatMap (p: p.arch) selected);
    nixprint.driverAttrs =
      lib.unique (map (p: p.nixpkgs) (lib.filter (p: p.nixpkgs != null) driverSel));
  };
}

#
# nixprint — printing, declared.
#
# WHY IT IS ITS OWN MODULE. Printing is one of the last genuinely imperative corners of a
# workstation: a printer gets added once through a GUI, a driver package gets pulled in to make it
# work, and years later nobody remembers which of the three installed driver sets is the one
# actually claiming the queue. That is fine until a rebuild, and then it is not.
#
# This module does NOT touch queues. Adding a printer is a runtime act against CUPS, and CUPS keeps
# that state in /etc/cups/printers.conf; re-declaring it here would fight the daemon for ownership
# of something it manages perfectly well. What is declared is the SUPPORTING SET -- which drivers
# are present, whether discovery works, whether there is a PDF pseudo-printer -- because that is
# the part that silently rots.
#
# So: a working printer stays working. This makes the packages behind it intentional, nothing more.
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
    enable = lib.mkEnableOption "printing: CUPS plus a declared driver set";

    drivers = mkGroup "printer driver sets to install" cat.drivers;
    extras = mkGroup "optional printing extras" cat.extras;

    discovery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install and enable mDNS/Bonjour discovery for network printers (avahi + nss-mdns).

        Both, deliberately: avahi finds the printer, nss-mdns is what lets glibc resolve the
        resulting .local name. With only the first, a discovered printer is visible and
        unreachable, which is a confusing way to spend an afternoon.
      '';
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selected packages as pacman names, for a host's own reconciler to consume.";
    };

    driverAttrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      internal = true;
      description = "nixpkgs attribute names of the selected drivers, for services.printing.drivers.";
    };
  };

  config = {
    nixprint.archPackages = lib.unique (map (p: p.arch) selected);
    nixprint.driverAttrs =
      lib.unique (map (p: p.nixpkgs) (lib.filter (p: p.nixpkgs != null) driverSel));
  };
}

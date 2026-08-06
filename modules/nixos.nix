# NixOS backend — drives services.printing and reconciles only nixprint-managed CUPS queues.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixprint;
  resolve = n: lib.attrByPath (lib.splitString "." n) null pkgs;
  drivers = lib.filter (d: d != null) (map resolve cfg.driverAttrs);
  queueReconciler = import ../lib/reconcile-queues.nix {
    inherit lib pkgs cfg;
    name = "nixprint-nixos-queues";
    programs = {
      lpadmin = "${pkgs.cups}/bin/lpadmin";
      lpstat = "${pkgs.cups}/bin/lpstat";
      cupsenable = "${pkgs.cups}/bin/cupsenable";
      # Nixpkgs installs the canonical CUPS command, not the legacy System V
      # `accept` alias. Keep both backends on the command that actually ships.
      accept = "${pkgs.cups}/bin/cupsaccept";
    };
  };
in
{
  imports = [ ./nixprint.nix ];

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      inherit drivers;
    };

    # cups-pdf is a service on NixOS, not a package: services.printing.cups-pdf wires its own
    # wrapped driver (the binary needs to run as root to reassign ownership of what it writes).
    # Selecting the "pdf-printer" extra therefore flips an option rather than installing anything.
    services.printing.cups-pdf.enable = lib.mkIf (lib.elem "pdf-printer" cfg.extras) true;

    # CUPS resolves dnssd:// queue URIs through Avahi. Resolver policy for arbitrary .local names
    # belongs to the host, not the printing module.
    services.avahi = lib.mkIf cfg.discovery {
      enable = true;
      openFirewall = true;
    };

    systemd.services.nixprint-reconcile = {
      description = "nixprint: reconcile managed CUPS queues";
      wantedBy = [ "multi-user.target" ];
      wants = [ "cups.service" ];
      after = [ "cups.service" ];
      restartTriggers = [ queueReconciler ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = queueReconciler;
      };
    };

    warnings = lib.optional (cfg.drivers == [ ])
      "nixprint: enabled with no drivers selected. CUPS will run, but only printers with built-in or IPP-Everywhere support will work.";
  };
}

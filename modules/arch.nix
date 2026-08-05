# System-manager backend. The host reconciler installs archPackages; this service starts CUPS and
# Avahi, preserves the selected support packages through an explicit install reason, removes only
# reviewed retired packages, then converges the queues through CUPS itself.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixprint;
  queueReconciler = import ../lib/reconcile-queues.nix {
    inherit lib pkgs cfg;
    name = "nixprint-system-manager-queues";
    modelForPrinter = printer:
      if printer.systemManagerModel == null then printer.model else printer.systemManagerModel;
    programs = {
      lpadmin = "/usr/bin/lpadmin";
      lpstat = "/usr/bin/lpstat";
      cupsenable = "/usr/bin/cupsenable";
      accept = "/usr/bin/accept";
    };
  };

  reconcile =
    assert lib.intersectLists cfg.archPackages cfg.retiredArchPackages == [ ];
    pkgs.writeShellScript "nixprint-system-manager-reconcile" ''
      set -euo pipefail

      /usr/bin/systemctl enable --now cups.service avahi-daemon.service
      /usr/bin/pacman -D --asexplicit ${lib.escapeShellArgs cfg.archPackages}

      retired=()
      for package in ${lib.escapeShellArgs cfg.retiredArchPackages}; do
        if /usr/bin/pacman -Q "$package" >/dev/null 2>&1; then
          retired+=("$package")
        fi
      done
      if [ "''${#retired[@]}" -gt 0 ]; then
        /usr/bin/pacman -Rns --noconfirm "''${retired[@]}"
      fi

      exec ${queueReconciler}
    '';
in
{
  imports = [ ./nixprint.nix ];

  config = lib.mkIf cfg.enable {
    systemd.services.nixprint-reconcile = {
      description = "nixprint: reconcile Arch printing packages and CUPS queues";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "nixarch-packages-reconcile.service" ];
      restartTriggers = [ reconcile ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = reconcile;
      };
    };
  };
}

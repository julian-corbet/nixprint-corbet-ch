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
      # Arch installs the CUPS command under its unambiguous upstream name;
      # `accept` is the legacy System V alias and is not packaged.
      accept = "/usr/bin/cupsaccept";
    };
  };

  reconcile =
    assert lib.intersectLists cfg.archPackages cfg.retiredArchPackages == [ ];
    pkgs.writeShellScript "nixprint-system-manager-reconcile" ''
      set -euo pipefail

      # Another converger (e.g. the host's package reconciler) may hold pacman's
      # exclusive database lock right now: systemd After= ordering does not
      # serialize oneshots that an activation restarts concurrently. Wait out a
      # live transaction; a lock that outlives the wait is stale, and pacman's
      # own diagnostic is the right error to surface then.
      wait_for_pacman() {
        local i=0
        while [ -e /var/lib/pacman/db.lck ] && [ "$i" -lt 150 ]; do
          ${pkgs.coreutils}/bin/sleep 2
          i=$((i + 1))
        done
      }

      /usr/bin/systemctl enable --now cups.service avahi-daemon.service
      wait_for_pacman
      /usr/bin/pacman -D --asexplicit ${lib.escapeShellArgs cfg.archPackages}

      retired=()
      for package in ${lib.escapeShellArgs cfg.retiredArchPackages}; do
        if /usr/bin/pacman -Q "$package" >/dev/null 2>&1; then
          retired+=("$package")
        fi
      done
      if [ "''${#retired[@]}" -gt 0 ]; then
        wait_for_pacman
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

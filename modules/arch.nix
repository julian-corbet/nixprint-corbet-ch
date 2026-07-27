# Arch backend — publishes the package list; the host reconciler installs it.
#
#   nixarch.packages.pacman = config.nixprint.archPackages;
#
# Enabling cups.service is deliberately NOT done here. On a machine that already prints, the
# service is already enabled and its queues already exist; asserting ownership of the unit would
# be this module's first act being to restart a working daemon.
{ ... }:
{
  imports = [ ./nixprint.nix ];
}

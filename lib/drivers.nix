#
# The printing catalogue: driver sets and the surrounding stack, named per platform.
#
# `arch` is the pacman package. `nixpkgs` is the attribute -- but note that on NixOS most of these
# are not installed as system packages at all: they go into `services.printing.drivers`, which is
# what modules/nixos.nix does with them. The attribute is still the right thing to name, because
# that option takes derivations.
{ ... }:
{
  # ── Driver sets ─────────────────────────────────────────────────────────────────────────────
  # More than one is normal and not redundant: foomatic supplies PPDs for a huge range of models,
  # gutenprint drives many inkjet/laser families directly, and hplip is HP's own stack. Which one
  # actually claims a given printer is decided by CUPS at queue-creation time, not here.
  drivers = {
    hplip = { arch = "hplip"; nixpkgs = "hplip"; };
    gutenprint = { arch = "gutenprint"; nixpkgs = "gutenprint"; };
    foomatic = { arch = "foomatic-db"; nixpkgs = "foomatic-db"; };
    foomatic-engine = { arch = "foomatic-db-engine"; nixpkgs = "foomatic-db-engine"; };
    foomatic-nonfree = { arch = "foomatic-db-nonfree"; nixpkgs = "foomatic-db-nonfree"; };
    splix = { arch = "splix"; nixpkgs = "splix"; };
  };

  # ── The stack around CUPS ───────────────────────────────────────────────────────────────────
  core = {
    cups = { arch = "cups"; nixpkgs = "cups"; };
    filters = { arch = "cups-filters"; nixpkgs = "cups-filters"; };
    ghostscript = { arch = "ghostscript"; nixpkgs = "ghostscript"; };
  };

  # ── Optional extras ─────────────────────────────────────────────────────────────────────────
  extras = {
    # nixpkgs has no cups-pdf PACKAGE to install. NixOS provides it as a service option
    # (services.printing.cups-pdf, which wires its own wrapped driver), so the NixOS backend
    # enables that instead of installing anything -- see modules/nixos.nix. null here is correct
    # and not a gap: naming a package would be naming one that does not exist.
    pdf-printer = { arch = "cups-pdf"; nixpkgs = null; };
    gui = { arch = "system-config-printer"; nixpkgs = "system-config-printer"; };
  };

  # ── Network discovery ───────────────────────────────────────────────────────────────────────
  # avahi alone is not enough: nss-mdns is what teaches glibc to resolve .local names, without
  # which a discovered printer is visible but unreachable by hostname.
  discovery = {
    avahi = { arch = "avahi"; nixpkgs = "avahi"; };
    nss-mdns = { arch = "nss-mdns"; nixpkgs = "nssmdns"; };
  };
}

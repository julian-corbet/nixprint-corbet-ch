# nixprint

Printing declared: CUPS, selected driver sets, DNS-SD discovery, and the queues that use them.

The problem this solves: a printer gets added once through a GUI, a driver package gets pulled in
somewhere to make it work, and years later nobody knows which driver or queue settings matter. On a
fresh host or after cleanup, that state disappears. nixprint makes the package set and named CUPS
queues reviewable Nix configuration, then reconciles the queues through CUPS' own `lpadmin` API.

## What nixprint is

A platform-neutral printing policy with NixOS and system-manager backends. It declares the
**supporting set** and the named queues that consume it. It exists in three forms:

- `modules/nixprint.nix`: policy, driver selection, and `nixprint.printers` queue declarations.
- `modules/nixos.nix`: installs drivers via `services.printing.drivers`, enables Avahi discovery,
  and reconciles queues with the NixOS CUPS binaries.
- `modules/arch.nix`: publishes `nixprint.archPackages`, then uses the host's CUPS and pacman to
  converge services, reviewed package retirements, and queues.

A host selects from several independent driver sets (hplip for HP printers, gutenprint for many
inkjet and laser families, foomatic for a huge range of models). Each queue supplies the exact
CUPS model identifier reported by `lpinfo -m`, so its driver choice is explicit rather than an
accident of queue creation. A queue may set `systemManagerModel` when Arch packages expose the
same driver through a different CUPS model identifier than NixOS.

## Queue lifecycle

- **CUPS remains the runtime owner.** nixprint never writes `printers.conf`; it uses `lpadmin`,
  `cupsenable`, and `cupsaccept`, exactly as a CUPS administrator would.
- **Managed queues are bidirectional.** nixprint records only the queue names it created. Removing
  one from `nixprint.printers` removes that queue on the next reconciliation, while manual queues
  are never touched.
- **Default and sharing policy are declared.** A managed queue can be the system default and can
  explicitly remain local instead of turning every client into a print server.

## What it explicitly does not own

- **Printer network connectivity.** Avahi enables CUPS DNS-SD discovery, but whether a specific
  printer is online and reachable remains outside the host configuration.
- **Print job management or monitoring.** CUPS owns the queue, the jobs, and the spooler. This
  module only declares its durable configuration.
- **Postscript or PDF rendering quality tuning.** Installing ghostscript (which CUPS uses to convert
  jobs) is here. How ghostscript renders fonts, compression, or color is not.
- **Manual queues outside its manifest.** They remain available for temporary diagnostics and are
  never deleted merely because nixprint is enabled.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), and `nixprint.nix` (the module). |
| `modules/` | Platform backends: `nixos.nix` (CUPS service and queue reconciliation) and `arch.nix` (system-manager reconciliation). |
| `lib/drivers.nix` | The driver catalogue: one entry per selectable driver set or extra, with platform-specific package names. |

## Platform support

**NixOS:** Full. Driver selections resolve to nixpkgs attributes; the NixOS backend installs via
`services.printing.drivers`. Avahi DNS-SD discovery toggles via `nixprint.discovery`.

**Arch / CachyOS (via system-manager):** Publishes `nixprint.archPackages` for the host's
reconciler, enables CUPS and Avahi, and converges declared queues. `retiredArchPackages` is an
explicit, narrow cleanup list; it is not a broad package-pruning switch.

## Related projects

Part of the same independently-usable NixOS module family: [nixdev](https://github.com/julian-corbet/nixdev-corbet-ch)
(operator tooling), [nixfont](https://github.com/julian-corbet/nixfont-corbet-ch) (fonts as a shared
concern), [nixoffice](https://github.com/julian-corbet/nixoffice-corbet-ch) (documents half of a
workstation), and [nixram](https://github.com/julian-corbet/nixram-corbet-ch) (memory-pressure tuning).

## License

MIT License &copy; 2026 Julian Corbet

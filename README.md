# nixprint

Printing declared: CUPS, a chosen driver set, and discovery that actually resolves to a working
queue — replacing the invisible accumulation of printer drivers and the mystery of which one is
actually claiming a queue at rebuild time.

The problem this solves: printing is one of the last genuinely imperative corners of a workstation.
A printer gets added once through a GUI, a driver package gets pulled in somewhere to make it work,
and years later nobody remembers which of the three installed driver sets is the one actually
claiming the queue. On a rebuild, something silently gets cleaned up, and the printer stops working.
This module is how that gap closes: you declare *which* driver sets are present (hplip, gutenprint,
foomatic), whether discovery works, whether there is a PDF pseudo-printer, and those packages become
intentional instead of accumulating by accident.

## What nixprint is

A platform-neutral NixOS module that declares the **supporting set** for printing — the packages
and services around CUPS that ensure drivers are present and discoverable — without touching queue
configuration itself. It exists in three forms:

- `nixprint.nix`: the declarative policy, selection logic, and the contract for what gets installed.
- `modules/nixos.nix`: the NixOS backend, which installs drivers via `services.printing.drivers`
  (not `environment.systemPackages`) and toggles discovery via `services.avahi`.
- `modules/arch.nix`: the Arch / system-manager backend, which publishes `nixprint.archPackages`
  for the host's own reconciler to consume.

A host selects from several independent driver sets (hplip for HP printers, gutenprint for many
inkjet and laser families, foomatic for a huge range of models) because more than one is normal
and not redundant — which driver actually claims a given printer is decided by CUPS at queue-creation
time, not by this module.

## What it explicitly does not own

- **Queue configuration.** Adding a printer is a runtime act against CUPS through its GUI or `lpadmin`.
  CUPS keeps queue state in `/etc/cups/printers.conf`. Declaring that state here would fight the
  daemon for ownership of something it manages perfectly well. This module declares the **packages**
  behind a working queue, not the queues themselves.
- **Printer network connectivity or discovery mechanics.** Installing avahi and nss-mdns (network
  discovery) is this module's concern. Whether a specific printer is on the network, reachable, or
  has been added to a queue is not.
- **Print job management or monitoring.** CUPS owns the queue, the jobs, and the spooler. This
  module only ensures the supporting infrastructure is present.
- **Postscript or PDF rendering quality tuning.** Installing ghostscript (which CUPS uses to convert
  jobs) is here. How ghostscript renders fonts, compression, or color is not.
- **PPD file management.** Driver packages bring PPD files (the printer descriptions CUPS reads).
  Editing or tuning them per-printer belongs to CUPS administration, not here.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), and `nixprint.nix` (the module). |
| `modules/` | Platform backends: `nixos.nix` (wires `services.printing.drivers` and `services.avahi`) and `arch.nix` (publishes package lists). |
| `lib/drivers.nix` | The driver catalogue: one entry per selectable driver set or extra, with platform-specific package names. |

## Platform support

**NixOS:** Full. Driver selections resolve to nixpkgs attributes; the NixOS backend installs via
`services.printing.drivers`. Discovery (avahi + nss-mdns) toggled via `nixprint.discovery`.

**Arch / CachyOS (via system-manager):** Publishes `nixprint.archPackages` for the host's
reconciler to consume. Cannot install packages or enable services itself. Discovery must be
configured separately.

## Related projects

Part of the same independently-usable NixOS module family: [nixdev](https://github.com/julian-corbet/nixdev-corbet-ch)
(operator tooling), [nixfont](https://github.com/julian-corbet/nixfont-corbet-ch) (fonts as a shared
concern), [nixoffice](https://github.com/julian-corbet/nixoffice-corbet-ch) (documents half of a
workstation), and [nixram](https://github.com/julian-corbet/nixram-corbet-ch) (memory-pressure tuning).

## License

MIT License &copy; 2026 Julian Corbet

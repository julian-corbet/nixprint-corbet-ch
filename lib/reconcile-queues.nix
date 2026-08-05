{ lib, pkgs, cfg, programs, name, modelForPrinter ? (printer: printer.model) }:
let
  queueNames = lib.attrNames cfg.printers;
  escape = lib.escapeShellArg;

  staleQueueCheck =
    if queueNames == [ ] then
      ''
        if ${programs.lpstat} -p "$queue" >/dev/null 2>&1; then
          ${programs.lpadmin} -x "$queue"
        fi
      ''
    else
      ''
        case "$queue" in
          ${lib.concatStringsSep "|" (map escape queueNames)})
            ;;
          *)
            if ${programs.lpstat} -p "$queue" >/dev/null 2>&1; then
              ${programs.lpadmin} -x "$queue"
            fi
            ;;
        esac
      '';

  queueOptions = printer:
    let
      effective = printer.ppdOptions // {
        "printer-is-shared" = if printer.shared then "true" else "false";
      };
    in
    lib.concatStringsSep " " (
      lib.mapAttrsToList (option: value: "-o ${escape "${option}=${value}"}") effective
    );

  ensureQueue = queue: printer:
    let
      model = modelForPrinter printer;
    in
    ''
      ${programs.lpadmin} -p ${escape queue} -v ${escape printer.deviceUri} -m ${escape model} -E${
        lib.optionalString (printer.location != null) " -L ${escape printer.location}"
      }${
        lib.optionalString (printer.description != null) " -D ${escape printer.description}"
      } ${queueOptions printer}
      ${programs.cupsenable} ${escape queue}
      ${programs.accept} ${escape queue}
    '';

  manifest =
    if queueNames == [ ] then
      ": > \"$tmp_file\""
    else
      lib.concatMapStrings (queue: "printf '%s\\n' ${escape queue} >> \"$tmp_file\"\n") queueNames;
in
assert cfg.defaultPrinter == null || builtins.hasAttr cfg.defaultPrinter cfg.printers;
pkgs.writeShellScript name ''
  set -euo pipefail

  state_dir=/var/lib/nixprint
  state_file="$state_dir/managed-queues"
  ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

  if [ -r "$state_file" ]; then
    while IFS= read -r queue || [ -n "$queue" ]; do
      [ -n "$queue" ] || continue
      ${staleQueueCheck}
    done < "$state_file"
  fi

  ${lib.concatMapStrings (queue: ensureQueue queue cfg.printers.${queue}) queueNames}
  ${lib.optionalString (cfg.defaultPrinter != null) "${programs.lpadmin} -d ${escape cfg.defaultPrinter}"}

  tmp_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/managed-queues.XXXXXX")"
  ${manifest}
  ${pkgs.coreutils}/bin/mv "$tmp_file" "$state_file"
''

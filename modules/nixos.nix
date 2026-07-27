# NixOS backend — drives services.printing rather than installing packages by hand.
#
# On NixOS, printing is a service with a `drivers` list, not a pile of system packages. Putting
# hplip into environment.systemPackages would install it without CUPS ever finding its PPDs, which
# is a very confusing kind of "installed but does nothing".
{ config, lib, pkgs, ... }:
let
  cfg = config.nixprint;
  resolve = n: lib.attrByPath (lib.splitString "." n) null pkgs;
  drivers = lib.filter (d: d != null) (map resolve cfg.driverAttrs);
in
{
  imports = [ ./nixprint.nix ];

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      inherit drivers;
    };

    # Discovery is two halves; nssmdns is the half everyone forgets.
    services.avahi = lib.mkIf cfg.discovery {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    warnings = lib.optional (cfg.drivers == [ ])
      "nixprint: enabled with no drivers selected. CUPS will run, but only printers with built-in or IPP-Everywhere support will work.";
  };
}

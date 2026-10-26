{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.autodesk-inventor;
  defaultPackages = {
    "2026" = self.packages.x86_64-linux.inventor;
    "2027" = self.packages.x86_64-linux.inventor-2027;
  };
  packageFor =
    year: if year == "2026" then cfg.package else cfg.packages.${year} or defaultPackages.${year};
  desktop = import ./desktop.nix { inherit pkgs packageFor; };
  newestYear =
    if cfg.versions == [ ] then "2026" else lib.last (lib.sort builtins.lessThan cfg.versions);
in
{
  options.programs.autodesk-inventor = {
    enable = lib.mkEnableOption "Autodesk Inventor through Wine and nix-overlayfs";
    versions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "2026"
          "2027"
        ]
      );
      default = [ "2026" ];
      description = "Inventor releases to install, each with separate persistent state.";
    };
    packages = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Packages by release, optionally overridden with lib.mkInventor.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = cfg.packages."2026" or defaultPackages."2026";
      description = "Inventor 2026 package; can also be set through packages.\"2026\".";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.versions != [ ] && lib.unique cfg.versions == cfg.versions;
        message = "programs.autodesk-inventor.versions must contain at least one release, without duplicates.";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "Autodesk Inventor currently supports x86_64-linux only.";
      }
    ];
    home.packages = [
      desktop.icons
    ]
    ++ lib.concatMap (year: [ (packageFor year) ] ++ desktop.entriesFor year) cfg.versions;
    xdg.mimeApps = {
      enable = true;
      defaultApplications."x-scheme-handler/adskidmgr" = [
        "${desktop.desktopNameFor newestYear}.desktop"
      ];
    };
  };
}

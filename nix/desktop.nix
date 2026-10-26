{ pkgs, packageFor }:
let
  inherit (pkgs) lib;
  desktopNameFor = year: if year == "2026" then "autodesk-inventor" else "autodesk-inventor-${year}";
  desktopFor =
    year:
    pkgs.makeDesktopItem {
      name = desktopNameFor year;
      desktopName = "Autodesk Inventor ${year}";
      icon = "inventor-on-linux";
      exec = "${lib.getExe (packageFor year)} %U";
      terminal = false;
      categories = [
        "Graphics"
        "Engineering"
      ];
      mimeTypes = [ "x-scheme-handler/adskidmgr" ];
    };
  waylandDesktopFor =
    year:
    pkgs.makeDesktopItem {
      name = "${desktopNameFor year}-wayland";
      desktopName = "Autodesk Inventor ${year} (Wayland)";
      icon = "inventor-on-linux";
      exec = "${pkgs.coreutils}/bin/env INVENTOR_WINE_DRIVER=wayland ${lib.getExe (packageFor year)} %U";
      terminal = false;
      categories = [
        "Graphics"
        "Engineering"
      ];
    };
in
{
  inherit desktopNameFor;
  entriesFor = year: [
    (desktopFor year)
    (waylandDesktopFor year)
  ];
  icons = pkgs.runCommand "autodesk-inventor-icons" { } ''
    for size in 16 24 32 48 64 128 256; do
      install -Dm644 ${../config/icons}/hicolor/''${size}x''${size}/inventor-on-linux.png \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/inventor-on-linux.png"
    done
    install -Dm644 ${../config/icons/inventor-on-linux.svg} \
      "$out/share/icons/hicolor/scalable/apps/inventor-on-linux.svg"
  '';
}

{ pkgs }:
{
  archive,
  name ? "inventor-media",
}:
pkgs.runCommand name
  {
    nativeBuildInputs = [ pkgs._7zz ];
    meta = {
      homepage = "https://www.autodesk.com/products/inventor/overview";
      license = pkgs.lib.licenses.unfree;
    };
  }
  ''
    mkdir -p "$out"
    7zz x -y -o"$out" ${pkgs.lib.escapeShellArg (toString archive)} > /dev/null
    test -f "$out/manifest/app.inventor.xml"
  ''

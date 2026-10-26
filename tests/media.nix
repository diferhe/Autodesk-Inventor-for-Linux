{ pkgs, mkMedia }:
let
  archive = pkgs.runCommand "inventor-fixture.7z" { nativeBuildInputs = [ pkgs._7zz ]; } ''
    mkdir manifest
    printf '%s\n' '<fixture />' > manifest/app.inventor.xml
    printf '%s\n' 'custom archive contents' > payload.txt
    7zz a -t7z "$out" manifest payload.txt > /dev/null
  '';
  media = mkMedia { inherit archive; };
  invalidArchive =
    pkgs.runCommand "inventor-invalid-fixture.7z" { nativeBuildInputs = [ pkgs._7zz ]; }
      ''
        printf '%s\n' 'no installer manifest' > payload.txt
        7zz a -t7z "$out" payload.txt > /dev/null
      '';
  invalidMedia = mkMedia { archive = invalidArchive; };
in
pkgs.runCommand "inventor-media-tests" { nativeBuildInputs = [ pkgs._7zz ]; } ''
  test "$(cat ${media}/manifest/app.inventor.xml)" = '<fixture />'
  test "$(cat ${media}/payload.txt)" = 'custom archive contents'
  if (export out="$TMPDIR/invalid-media"; bash -e -c ${pkgs.lib.escapeShellArg invalidMedia.buildCommand}); then
    echo 'Media without an installer manifest was accepted' >&2
    exit 1
  fi
  touch "$out"
''

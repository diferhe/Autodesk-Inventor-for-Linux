# NixOS setup

> **Do not upload Inventor to a public binary cache.** The built Inventor package
> contains Autodesk’s proprietary software. Publishing it to Cachix or any other
> public binary cache would redistribute that software and must never be done.
> This also applies to Autodesk installation media, extracted images, application
> layers, and cache uploads of a system closure that includes Inventor.

The exact pinned Inventor package builds, and `nix flake check` passes.
The built application layer contains the verified x86-64 `Inventor.exe`,
packaged fonts, and valid licensing and Identity Manager links. Fresh-state
GUI validation passed browser sign-in and basic part creation, save, and reopen.
Broader application compatibility has not been validated.

The default target is Inventor Professional 2026 English with the 2026.4 update
and Content Center, on x86_64 Linux. Inventor 2027 English with update 2027.1
is also available as a separate package. The runtime builds Wine 11.20 with every
top-level patch in `patches/`. Nixpkgs and the nix-overlayfs fork are pinned in
`flake.lock`; no local checkout is required by the committed input definitions.
The pinned nix-overlayfs revision includes Wine 11.20's Mono 11.3.0 dependency
mapping and sandbox MSI link-action fix, published from the local development
fork. That base environment builds successfully with the patched Wine runtime.
The pinned library also preserves Wine's registry symbolic-link markers and
propagates failed installer exit statuses. The WebView2 layer has been built
and checked for its actual executable. The Inventor base image, all 21 selected
installation steps, the 2026.4 update, and final configuration completed in the
Nix sandbox. The library's opt-in portable directory-reparse support preserves
installer junctions without changing host security policy; its FUSE ownership
mapping allows runtime modification of packaged files.
A separate libgsf patch fixes empty OLE streams; it was
verified by rebuilding msitools with all 29 of its tests enabled and passing.

## Installation media

Obtain your own direct downloads from Autodesk. Import these original files:

```sh
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 "$HOME/downloads/Inventor/Inventor_Professional_2026_English_Win_64bit_db_002_002.7z")"
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 "$HOME/downloads/Inventor/Inventor_2026.4_Update.exe")"
```

For Inventor 2027, import its own archive and update instead (import both sets
when installing both releases):

```sh
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 "$HOME/downloads/Inventor/2027/Inventor_Professional_2027_English_Win_64bit_db_002_002.7z")"
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 "$HOME/downloads/Inventor/2027/Inventor_2027.1_Update.exe")"
```

The small `001_002.exe` unpacker is unnecessary. The archive and update must
match the hashes in `nix/media.nix`.

### Check the imported files

Compare the printed hashes with `sources."2026".archiveHash` and
`sources."2026".updateHash` in `nix/media.nix`. For 2027, use its files and the
corresponding `sources."2027"` values.

The filename must also match the relevant `requireFile` name in `nix/media.nix`.
If your download has a different hash, follow
[Custom installer archives and updates](#custom-installer-archives-and-updates)
to supply it explicitly.

### Build and launch

Installation runs from original media in a build prefix; existing personal
prefixes are not used as package sources.
Autodesk media, updates, the installed application, and Microsoft WebView2 are
marked unfree. This application flake explicitly enables unfree packages in its
private Nixpkgs instance; it does not change your system-wide Nixpkgs policy.

```sh
nix flake check
nix build .#inventor
nix run .#inventor
```

When developing with new files that have not yet been added to Git, use
`path:$PWD` as the flake reference, for example `nix build "path:$PWD#inventor"`.

## Declarative integration

Requires x86_64 NixOS with flakes enabled and Vulkan-capable system graphics
drivers. Keep your existing Nixpkgs input, hardware configuration, and GPU driver
settings. Add the following sections to your system configuration.

### 1. Add the flake input

Inside your system `flake.nix`, add this alongside your existing inputs:

```nix
inputs.inventor.url = "github:Harvi654/Autodesk-Inventor-for-Linux";
```

Commit the resulting `flake.lock` so the repository revision is pinned. Leave
Inventor's own Nixpkgs input pinned as supplied by this project.

### 2. Wire the module into your host

In the same `flake.nix`, include `inputs` in the outputs arguments and add both
the project's module and a local `inventor.nix` module to your existing host's
`modules` list. Replace `your-host` with your existing configuration name:

```nix
outputs = inputs@{ nixpkgs, ... }: {
  nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      inputs.inventor.nixosModules.default
      ./inventor.nix
    ];
  };
};
```

Create `inventor.nix` beside your system flake:

```nix
{ lib, ... }:
{
  programs.autodesk-inventor.enable = true;

  # Optional narrow system policy; the default package also works without it.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "inventor"
      "inventor-overlay"
    ];
}
```

`inventor` names the installed application layer; `inventor-overlay` names the
launcher package. The flake already enables its proprietary Autodesk media,
update, and Microsoft WebView2 dependencies in its own private Nixpkgs instance,
so you do not need to list those sources in your system's predicate or set
`nixpkgs.config.allowUnfree = true` globally. The predicate above is optional;
if you already maintain an allowlist, add these two names to it instead of
replacing it. If you already enable all unfree packages, omit the predicate.
For the minimal setup, `inventor.nix` can contain just:

```nix
{
  programs.autodesk-inventor.enable = true;
}
```

For a local checkout, use `path:/absolute/path/to/Autodesk-Inventor-for-Linux`
as the input URL instead. The initial build compiles patched Wine and can take
substantial time and disk space.

### 3. Rebuild and launch

After importing the installation media above, rebuild your system and launch
Inventor (replace the path and `your-host`):

```sh
sudo nixos-rebuild switch --flake /path/to/system-flake#your-host
inventor
```

Or select **Autodesk Inventor 2026** in your application menu. Complete first
sign-in in your normal browser and allow the Autodesk callback to open Inventor.

The module installs the application and desktop entry, enables NixOS graphics
and FUSE support, and associates `adskidmgr://` links with the launcher. nix-overlayfs
forwards callbacks to Identity Manager in the active composed prefix and
provides browser integration. Sign-in requires your Autodesk account and license.

If Home Manager already manages your user MIME defaults, set its association
too; a user default takes precedence over the system default:

```nix
xdg.mimeApps.defaultApplications."x-scheme-handler/adskidmgr" = "autodesk-inventor.desktop";
```

## Home Manager integration

The flake also exports `homeManagerModules.default`. Use it in your existing
Home Manager configuration instead of the NixOS application module when you want
to manage Inventor for one user. On NixOS, the host still needs graphics and FUSE:

```nix
hardware.graphics.enable = true;
programs.fuse.enable = true;
```

Pass `inputs` through Home Manager's `extraSpecialArgs` (or
`home-manager.extraSpecialArgs` when using its NixOS module). In your `home.nix`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.inventor.homeManagerModules.default ];

  programs.autodesk-inventor = {
    enable = true;
    versions = [ "2026" "2027" ];
  };
}
```

Omit `versions` for 2026 only, or use `[ "2027" ]` for 2027 only. The module
installs the selected packages, icons, regular and experimental Wayland desktop
entries, and the user's browser callback association. It enables
`xdg.mimeApps` and selects the newest installed release for `adskidmgr` links.
The regular launcher uses XWayland; see [Native Wayland limitation](#native-wayland-limitation).

Both modules expose the same `versions`, `packages`, and `package` options.
Use `packages."2026"` or `packages."2027"` for per-release overrides; `package`
is an alternative override for 2026 and takes precedence when explicitly set.
Use one module to manage a given user's installation and callback defaults.

## Install both releases side by side

The NixOS module keeps the existing 2026-only default. To install both releases:

```nix
programs.autodesk-inventor = {
  enable = true;
  versions = [ "2026" "2027" ];
};
```

Use `versions = [ "2027" ];` for 2027 only. Each release has its own desktop
entry, Wine prefix, licensing database, lock, settings, and logs. The commands
are `inventor` for 2026 and `inventor-2027` for 2027. From the checkout, use
`nix run .#inventor-2026` or `nix run .#inventor-2027`; `.#inventor` remains 2026.
Native Wayland remains experimental for both releases.

The module's browser callback default selects the newest installed release.
If Home Manager manages MIME defaults and you install 2027, use
`"autodesk-inventor-2027.desktop"` instead of `"autodesk-inventor.desktop"`.
The launcher also registers a release-specific callback handler when started;
complete sign-in for one release at a time when both are open.

For custom 2027 media, set `programs.autodesk-inventor.packages."2027"` to a
package made with `inputs.inventor.lib.mkInventor { year = "2027"; ...; }`.
The existing `programs.autodesk-inventor.package` override still targets 2026.

## Custom installer archives and updates

The built-in filename and hash in `nix/media.nix` identify a particular (tested) Autodesk
download. For another archive or update, supply your own hash-pinned
sources through the flake library. This does not require editing this repository.

`lib.mkMedia { archive = ...; }` extracts an original Autodesk installation
archive and checks for `manifest/app.inventor.xml` at its root. The built-in
archives use the same helper. `lib.mkInventor` accepts its
output through `media`. An already unpacked media derivation can also be supplied
directly. Update installers go in `updates` without extraction.

### Import local downloads

Import each original file and print its flat SHA-256 hash in one step:

```sh
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 /path/to/custom-installer.7z)"
nix hash file --type sha256 --sri "$(nix-store --add-fixed sha256 /path/to/custom-update.exe)"
```

Use each file's exact basename and reported hash in `requireFile`. For example,
this Home Manager module replaces the 2026 package:

```nix
{ inputs, pkgs, ... }:
let
  archive = pkgs.requireFile {
    name = "custom-installer.7z";
    hash = "sha256-REPLACE_WITH_ARCHIVE_HASH";
    message = "Import custom-installer.7z with nix-store --add-fixed sha256.";
  };
  update = pkgs.requireFile {
    name = "custom-update.exe";
    hash = "sha256-REPLACE_WITH_UPDATE_HASH";
    message = "Import custom-update.exe with nix-store --add-fixed sha256.";
  };
  inventor = inputs.inventor.lib.mkInventor {
    media = inputs.inventor.lib.mkMedia { inherit archive; };
    updates = [ update ];
    year = "2026";
    version = "2026.4"; # Match the supplied media and updates.
    contentCenter = false;
  };
in
{
  imports = [ inputs.inventor.homeManagerModules.default ];
  programs.autodesk-inventor = {
    enable = true;
    packages."2026" = inventor;
  };
}
```

For NixOS, use `inputs.inventor.nixosModules.default` in `imports` instead;
the package construction and `programs.autodesk-inventor` settings are identical.
Make `inputs` available through your NixOS configuration's `specialArgs` when
using it in a separate module.

For 2027, use its own media and updates, set `year = "2027"` and the matching
`version`, assign `packages."2027"`, and include `"2027"` in `versions`.
The year selects the installation paths and runtime state; `version` labels the
package and does not select an update. Set `updates = [ ];` to install only the
base media, or list multiple update installers in their required application
order. Content Center is included by default; `contentCenter = false` omits it.
The Nix installer currently selects `en-US`; replacing the archive alone does
not change the installation language.

### Use a hash-pinned download source

Either source can instead be a `pkgs.fetchurl` derivation, for example from a
private download endpoint you control. Replace the `archive` binding above with:

```nix
archive = pkgs.fetchurl {
  url = "https://downloads.example.internal/custom-installer.7z";
  hash = "sha256-REPLACE_WITH_ARCHIVE_HASH";
  meta.license = pkgs.lib.licenses.unfree;
};
```

The same substitution works for `update`. The URL must return the actual file,
not an interactive sign-in page. For Autodesk's account-based browser downloads,
use the local `requireFile` workflow above. If your own `pkgs` uses a restrictive
unfree allowlist, include the fetcher's package name in that list.

## Runtime state and upgrades

Changing an update or runtime rebuilds immutable layers; login and application
settings remain in nix-overlayfs's writable state at
`${XDG_DATA_HOME:-~/.local/share}/autodesk-inventor-2026` or
`${XDG_DATA_HOME:-~/.local/share}/autodesk-inventor-2027`.
Service logs are under `${XDG_STATE_HOME:-~/.local/state}/autodesk-inventor-<year>`.
Do not delete existing writable state when testing upgrades. Use temporary XDG
data/cache/state directories for clean smoke tests.

The launcher prepares each release's writable public `Macros` directory and
per-user `Addins` directory before startup, preserving existing files.

Launchers prevent overlapping sessions that share this state. The licensing
database is linked to `.nix-overlayfs/licensing-data/AdskLicensingService.sds`
inside the writable state directory so its memory-mapped file stays outside the
overlay mount. The first launch migrates the existing database without resetting
sign-in. Include this directory when backing up your installation's user state.

The launcher defaults to automatic namespace selection and the system graphics
stack at `/run/opengl-driver`. Keep the default host security policy. Diagnostics
can select `NIX_OVERLAYFS_NAMESPACE_MODE=direct` or
`NIX_OVERLAYFS_GRAPHICS_STACK=auto`.

## Build evidence

Validated on 2026-10-20 with the library pinned to
`8bf7c5cfa2541cf1478b87b519dcdc4c75831407`:

- `nix flake check`: passed, including seven installer boundary/regression tests.
- `nix build .#inventor --no-link --keep-failed -L`: passed.
- Application layer: `/nix/store/38y9yn20sg5nxi06fr6pfgh78v0a8g7l-inventor-2026.4`.
- Launcher: `/nix/store/kbrqwdmy6g8qmzd82s82x2fs137w6pgv-inventor-overlay-2026.4/bin/inventor`.
- `Inventor.exe`: PE signature and x86-64 machine type verified; 1,587,032 bytes.
- Required Noto Sans, Liberation Sans, and DejaVu Sans font files verified.
- All ten DXVK replacement DLLs retained in the captured layer.
- NixOS module evaluation confirms graphics, FUSE, and callback defaults.
- Relative `Current` links resolve to installed licensing and Identity Manager versions.
- Library tests: portable reparse metadata, installer failure propagation, direct
  builds, namespace/FUSE ownership, shared helper/application credentials,
  runtime cleanup, and browser callback VM checks passed.

## Runtime evidence

A fresh test state under `/tmp/inventor-flake-qa/data4` launched Inventor 2026.4,
displayed its licensing UI, handed sign-in to the user's normal browser, and
received the callback. Identity Manager reported a valid login, and the main
Inventor window opened. The user's original browser callback association was
restored afterward. Normal exit returned status 0 in both software-graphics and
system-graphics tests. System graphics detected the NVIDIA RTX 3060.

The user then ran the exact launcher above on the normal desktop with system
graphics and the separate authenticated test state. They confirmed creating a
basic part, saving it, closing and reopening it, and exiting Inventor. The saved
`nix-flake-smoke.ipt` is 132,608 bytes with the expected OLE compound-file header
(`d0cf11e0a1b11ae1`), SHA-256
`74e1513cb8c460b12322162e08f83bf45a33a20b295008d62c36164998f7ad1a`.
This completes the basic runtime smoke test; broader Inventor features and
performance have not been validated.

The hidden Xvfb desktop still stops at “Loading…” when creating a standard part
with either graphics setup. Its cause remains undetermined; the successful
normal-desktop test establishes the supported smoke-test result. The isolated
desktop was stopped, and the authenticated test state was preserved.

## Native Wayland limitation

Use the regular **Autodesk Inventor 2026** desktop entry on Wayland desktops;
it runs through XWayland and is the validated configuration. Native fractional
scaling is currently unavailable with this setup.

**Autodesk Inventor 2026 (Wayland)** remains an experimental entry and is not
working yet. It explicitly selects Wine’s `wayland` driver. On 2026-10-20 the
user confirmed that a window appears, but remains unresponsive after resolving
a separate sign-in/licensing issue. Native Wayland is therefore not a usable
alternative to the regular launcher at present. Close Inventor before changing
launchers because they share persistent state and the running Wine session.

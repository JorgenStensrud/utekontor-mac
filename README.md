# Utekontor

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="128" height="128" alt="Utekontor app icon">
</p>

Small native macOS menu bar app for:

- XDR boost toggle on likely supported displays
- built-in Mac brightness control
- one external monitor brightness slider over DDC
- one-way internal-to-external brightness sync
- optional XDR auto-off timer
- proper `.app` packaging for reliable menu bar launch

Utekontor is **free** and **open source** (MIT). It covers a small slice of what commercial tools often charge for; see [Acknowledgments](#acknowledgments) for the open-source projects that informed the approach (credit only—no bundled code, no affiliation).

## Current scope

- Apple Silicon first
- one external display only
- real `.app` built with `xcodebuild`
- no Xcode IDE required

## Build

```bash
cd /path/to/utekontor-mac
mkdir -p /tmp/clangcache
CLANG_MODULE_CACHE_PATH=/tmp/clangcache swift build
```

## Build app

```bash
cd /path/to/utekontor-mac
./Scripts/package_app.sh
open Utekontor.app
```

Default output (Debug):

```text
./.derived/Build/Products/Debug/Utekontor.app
```

Convenience symlink at repo root:

```text
./Utekontor.app
```

Build Release and open:

```bash
UTEKONTOR_CONFIGURATION=Release UTEKONTOR_OPEN_AFTER_BUILD=1 ./Scripts/package_app.sh
```

## Install to `/Applications`

After a successful `./Scripts/package_app.sh`:

```bash
./Scripts/install_to_applications.sh
```

Override destination or configuration:

```bash
UTEKONTOR_INSTALL_DIR="$HOME/Applications" UTEKONTOR_CONFIGURATION=Release ./Scripts/install_to_applications.sh
```

## GitHub releases and Homebrew

Build the zip used for releases and the Homebrew cask:

```bash
./Scripts/release_zip.sh
```

Maintainers: attach `dist/Utekontor-<version>.zip` to a [GitHub Release](https://github.com/JorgenStensrud/utekontor-mac/releases) with tag `v` plus the cask version (for example `v0.1.0`). Update `version` and `sha256` in `Casks/utekontor.rb` when the zip changes (`shasum -a 256` on the exact file you upload).

Users install from this repo as a tap:

```bash
brew tap JorgenStensrud/utekontor-mac https://github.com/JorgenStensrud/utekontor-mac
brew install --cask utekontor
```

## Acknowledgments

Utekontor is independent software. The following **open-source** macOS display projects are credited for ideas and prior art only (not shipped code, not endorsement):

- **[BrightIntosh](https://github.com/niklasr22/BrightIntosh)** — XDR / EDR-style brightness boost ([BrightIntosh app sources](https://github.com/niklasr22/BrightIntosh/tree/main/BrightIntosh))
- **[Lunar](https://github.com/alin23/Lunar)** — brightness, monitors, and DDC ecosystem
- **[MonitorControl](https://github.com/MonitorControl/MonitorControl)** — external monitor brightness over DDC

## Notes

- The XDR path is intentionally minimal; see [Acknowledgments](#acknowledgments).
- The DDC path currently assumes Apple Silicon and uses the first external `DCPAVServiceProxy` it can open.
- Expect monitor-specific variation. Some docks and cables do not pass DDC reliably.
- The preferred launch flow is the `xcodebuild`-produced `.app` (repo-root `Utekontor.app` symlink), not the raw SwiftPM binary, because macOS menu bar apps attach more reliably that way.

## License

MIT — see [LICENSE](LICENSE).

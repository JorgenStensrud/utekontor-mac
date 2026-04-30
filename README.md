# Utekontor

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="128" height="128" alt="Utekontor app icon">
</p>

Small native **macOS menu bar** app for brightness, XDR boost, and one external display over DDC—**free** and **open source** (MIT). See [Acknowledgments](#acknowledgments) for prior art (credit only; no bundled third-party code).

---

## Installation (Homebrew)

If you use [Homebrew](https://brew.sh), you do **not** need to build anything or copy the app into `Applications` by hand. The cask installs **`Utekontor.app` into `/Applications`** for you (Homebrew’s default app location).

```bash
brew tap JorgenStensrud/utekontor-mac https://github.com/JorgenStensrud/utekontor-mac
brew install --cask utekontor
```

To install only for your user (optional):

```bash
brew install --cask --appdir="$HOME/Applications" utekontor
```

**First launch:** open **Utekontor** from **Applications** (or Spotlight). If macOS blocks the app because it is not from the Mac App Store, use **System Settings → Privacy & Security** and choose **Open Anyway** once (typical for small OSS binaries that are not Apple-notarized).

---

## How to use Utekontor

1. Launch **Utekontor**; it runs as a **menu bar** app (no Dock icon by design).
2. Click the **sun / status icon** in the menu bar to open the menu and sliders.
3. Optional: **System Settings → General → Login Items** — add Utekontor if you want it at login.

**What it can do (today):**

- Toggle **XDR boost** on supported built-in displays (best-effort).
- Adjust **built-in Mac brightness**.
- One **external monitor** brightness slider over **DDC** (Apple Silicon; first external display only).
- **Sync** built-in brightness toward the external display (one-way).
- Optional **XDR auto-off** timer.

**Limitations:** Apple Silicon–first workflow; one external display; DDC varies by cable, dock, and monitor. See [Notes](#notes) below.

---

## Build from source (development)

Use this path if you are **hacking on the repo** or want a build without Homebrew. You need a recent **Xcode** (or at least Xcode Command Line Tools with a Swift toolchain that matches the project), and **macOS 13+** to match the deployment target.

### Clone

```bash
git clone https://github.com/JorgenStensrud/utekontor-mac.git
cd utekontor-mac
```

### Quick compile check (SwiftPM)

Does **not** produce the recommended menu-bar `.app`; useful for CI or editor tooling:

```bash
mkdir -p /tmp/clangcache
CLANG_MODULE_CACHE_PATH=/tmp/clangcache swift build
```

### Build the real `.app` (what you should run locally)

Uses **`xcodebuild`** and writes under `.derived/`, with a repo-root symlink **`Utekontor.app`**:

```bash
./Scripts/package_app.sh
open Utekontor.app
```

Debug output path:

```text
./.derived/Build/Products/Debug/Utekontor.app
```

Release build and open after a successful build:

```bash
UTEKONTOR_CONFIGURATION=Release UTEKONTOR_OPEN_AFTER_BUILD=1 ./Scripts/package_app.sh
```

### Copy your dev build into Applications (optional)

Only if **you** want your **self-built** app in `/Applications` while developing—**not** required for Homebrew users.

```bash
./Scripts/package_app.sh
./Scripts/install_to_applications.sh
```

Override folder or configuration:

```bash
UTEKONTOR_INSTALL_DIR="$HOME/Applications" UTEKONTOR_CONFIGURATION=Release ./Scripts/install_to_applications.sh
```

---

## Maintainers: releases and Homebrew checksum

```bash
./Scripts/release_zip.sh
```

Attach `dist/Utekontor-<version>.zip` to a [GitHub Release](https://github.com/JorgenStensrud/utekontor-mac/releases) whose tag is `v` plus the cask version (e.g. `v0.1.0`). Update `version` and `sha256` in `Casks/utekontor.rb` to match the uploaded zip (`shasum -a 256` on that file).

---

## Acknowledgments

Utekontor is independent software. The following **open-source** macOS display projects are credited for ideas and prior art only (not shipped code, not endorsement):

- **[BrightIntosh](https://github.com/niklasr22/BrightIntosh)** — XDR / EDR-style brightness boost ([BrightIntosh app sources](https://github.com/niklasr22/BrightIntosh/tree/main/BrightIntosh))
- **[Lunar](https://github.com/alin23/Lunar)** — brightness, monitors, and DDC ecosystem
- **[MonitorControl](https://github.com/MonitorControl/MonitorControl)** — external monitor brightness over DDC

## Notes

- The XDR path is intentionally minimal; see [Acknowledgments](#acknowledgments).
- The DDC path assumes Apple Silicon and uses the first external `DCPAVServiceProxy` it can open.
- For **local development**, prefer opening the **`xcodebuild`** `.app` (`./Utekontor.app` after `./Scripts/package_app.sh`) rather than only the raw SwiftPM binary, so the menu bar session behaves reliably.

## License

MIT — see [LICENSE](LICENSE).

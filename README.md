# Utekontor ☀️

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="128" height="128" alt="Utekontor app-ikon">
</p>

> Sola skinner, du sitter ute, og MacBook-skjermen ser ut som en blank tallerken. **Utekontor** er en bitteliten menylinje-app som gir deg full XDR-boost, lysstyrke og DDC-kontroll over én ekstern skjerm — uten å åpne System Settings.

Liten, **native macOS menylinje-app** for lysstyrke, XDR-boost og én ekstern skjerm via DDC. **Gratis** og **åpen kildekode** (MIT). Se [Anerkjennelser](#anerkjennelser) for inspirasjon (kun kreditering — ingen tredjepartskode er bundlet).

> ⚠️ **Ansvarsfraskrivelse:** Hele appen er **bygget med AI**. Den er levert «as is», uten garantier av noe slag. Bruk på **eget ansvar** — XDR-boost gir varme og kan påvirke skjermens levetid, og DDC-kommandoer kan oppføre seg uforutsigbart med visse kabler, docker og skjermer. Hvis du ikke er komfortabel med det: ikke installer.

---

## Innhold

- [Installasjon (Homebrew)](#installasjon-homebrew)
- [Slik bruker du Utekontor](#slik-bruker-du-utekontor)
- [Bygg fra kildekode](#bygg-fra-kildekode)
- [Vedlikehold: releases og Homebrew-sjekksum](#vedlikehold-releases-og-homebrew-sjekksum)
- [Anerkjennelser](#anerkjennelser)
- [Tekniske notater](#tekniske-notater)
- [Lisens](#lisens)

---

## Installasjon (Homebrew)

Bruker du [Homebrew](https://brew.sh) trenger du **ikke** å bygge noe selv eller flytte appen til `Applications` manuelt. Cask-en installerer **`Utekontor.app` i `/Applications`** for deg (Homebrews standard-plassering).

```bash
brew tap JorgenStensrud/utekontor-mac https://github.com/JorgenStensrud/utekontor-mac
brew install --cask utekontor
```

Kun for din bruker (valgfritt):

```bash
brew install --cask --appdir="$HOME/Applications" utekontor
```

### Oppdatering

```bash
brew update
brew upgrade --cask utekontor
```

### Avinstallasjon

```bash
brew uninstall --cask utekontor
brew untap JorgenStensrud/utekontor-mac   # valgfritt
```

### Første oppstart

Åpne **Utekontor** fra **Applications** eller Spotlight. Distribusjons-builds er **signert med Apple Developer ID** og **notarisert hos Apple**, så Gatekeeper godtar appen uten advarsler ved første kjøring.

**Krav:** macOS **13 (Ventura)** eller nyere. Apple Silicon anbefales (DDC-stien er først og fremst testet på Apple Silicon).

---

## Slik bruker du Utekontor

1. Start **Utekontor** — den kjører i **menylinjen** (ingen Dock-ikon, by design).
2. Klikk **sol-/statusikonet** for å åpne menyen og slidere.
3. Valgfritt: **System Settings → General → Login Items** — legg til Utekontor for å få den ved innlogging.

**Hva den gjør i dag:**

- Slå **XDR-boost** av/på på støttede innebygde skjermer (best-effort).
- Justere **innebygd Mac-lysstyrke**.
- Lysstyrke for **én ekstern skjerm** via **DDC** (Apple Silicon, første tilkoblede eksterne skjerm).
- **Synk** av innebygd lysstyrke mot den eksterne (enveis).
- Valgfri **XDR auto-av**-timer.

**Begrensninger:** Apple Silicon-først, kun én ekstern skjerm, og DDC varierer med kabel, dock og skjerm. Se [Tekniske notater](#tekniske-notater).

---

## Bygg fra kildekode

For deg som vil **hacke på koden** eller bygge uten Homebrew. Du trenger:

- **Xcode 15+** (eller minst Xcode Command Line Tools med Swift-toolchain som matcher prosjektet)
- **macOS 13+** (deployment target)
- **Swift 6.0** toolchain

> 💡 **Swift vs. Xcode:** Selve koden er Swift. **Xcode** brukes som byggesystem (`xcodebuild`) for å produsere et signert `.app`-bundle med Info.plist, ikoner og menylinje-oppsett. Repoet har også en `Package.swift` for rask SwiftPM-kompilering, men den genererer **ikke** et kjørbart menylinje-`.app`.

### Klone

```bash
git clone https://github.com/JorgenStensrud/utekontor-mac.git
cd utekontor-mac
```

### Repo-struktur (kort)

```text
Sources/Utekontor/        Swift-kildekode
Resources/                Info.plist, Assets.xcassets, ikoner
Utekontor.xcodeproj/      Xcode-prosjekt (anbefalt byggesti)
Package.swift             SwiftPM (kun rask kompileringssjekk)
Scripts/
  package_app.sh          xcodebuild → .derived/.../Utekontor.app
  install_to_applications.sh
  release_zip.sh          Lager dist/Utekontor-<version>.zip + sha256
Casks/utekontor.rb        Homebrew cask-definisjon (denne repo er en tap)
```

### Rask kompileringssjekk (SwiftPM)

Genererer **ikke** den anbefalte menylinje-`.app`-en, men er nyttig for CI eller editor-tooling:

```bash
mkdir -p /tmp/clangcache
CLANG_MODULE_CACHE_PATH=/tmp/clangcache swift build
```

### Bygg ekte `.app` (det du faktisk skal kjøre lokalt)

Bruker **`xcodebuild`** under panseret, skriver til `.derived/`, og lager en symlink `Utekontor.app` i repo-roten:

```bash
./Scripts/package_app.sh
open Utekontor.app
```

Debug-utgangssti:

```text
./.derived/Build/Products/Debug/Utekontor.app
```

Release-build som åpnes automatisk etter vellykket bygg:

```bash
UTEKONTOR_CONFIGURATION=Release UTEKONTOR_OPEN_AFTER_BUILD=1 ./Scripts/package_app.sh
```

Miljøvariabler `package_app.sh` forstår:

| Variabel                       | Standard | Beskrivelse                          |
| ------------------------------ | -------- | ------------------------------------ |
| `UTEKONTOR_CONFIGURATION`      | `Debug`  | `Debug` eller `Release`              |
| `UTEKONTOR_OPEN_AFTER_BUILD`   | `0`      | Sett til `1` for å `open` etter bygg |

### Kopiér din dev-build til Applications (valgfritt)

Kun hvis **du** vil ha **din egenbygde** app i `/Applications` mens du utvikler — ikke nødvendig for Homebrew-brukere.

```bash
./Scripts/package_app.sh
./Scripts/install_to_applications.sh
```

Overstyr mappe eller konfigurasjon:

```bash
UTEKONTOR_INSTALL_DIR="$HOME/Applications" \
UTEKONTOR_CONFIGURATION=Release \
  ./Scripts/install_to_applications.sh
```

---

## Anerkjennelser

Utekontor er uavhengig programvare. Følgende **open source**-prosjekter for macOS-skjermkontroll er kreditert for idéer og prior art (ingen kode er kopiert, ingen endorsement):

- **[BrightIntosh](https://github.com/niklasr22/BrightIntosh)** — XDR / EDR-style brightness boost ([BrightIntosh app sources](https://github.com/niklasr22/BrightIntosh/tree/main/BrightIntosh))
- **[Lunar](https://github.com/alin23/Lunar)** — brightness, monitors og DDC-økosystem
- **[MonitorControl](https://github.com/MonitorControl/MonitorControl)** — ekstern lysstyrke over DDC

---

## Tekniske notater

- **XDR-stien** er bevisst minimal. Bruker EDR-headroom-API-er på støttede innebygde skjermer; oppførsel kan endres mellom macOS-versjoner.
- **DDC-stien** antar Apple Silicon og bruker den første eksterne `DCPAVServiceProxy`-en den klarer å åpne. Resultater varierer med USB-C/HDMI-kabler, docker og skjermfirmware.
- **Menylinje-livssyklus:** Foretrekk å åpne `xcodebuild`-bygget `.app` (`./Utekontor.app` etter `./Scripts/package_app.sh`) i stedet for SwiftPM-binaryen direkte — det gir et stabilt menylinje-økosystem (Info.plist, `LSUIElement`, ressurser).
- **Signering / notarisering:** Distribusjons-builds signeres med Apple Developer ID og notariseres hos Apple. Lokale dev-builds via `Scripts/package_app.sh` er usignerte og kjører kun på din egen maskin.

---

## Lisens

MIT — se [LICENSE](LICENSE).

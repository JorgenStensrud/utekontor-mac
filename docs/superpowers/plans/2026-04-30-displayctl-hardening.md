# Utekontor Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Utekontor from a raw SwiftPM menubar binary into a properly packaged macOS menubar app with cleaner status-item state flow and a custom icon.

**Architecture:** Keep the app SwiftPM-based, but add an app-bundling layer that emits a real `Utekontor.app` with `LSUIElement`. Split stateful behavior out of `AppController` into focused controller/model types so menu rendering, timer behavior, and app lifecycle are distinct responsibilities. Replace the temporary SF Symbol-only status item with a tiny state-aware template icon renderer.

**Tech Stack:** Swift 6.3, AppKit, CoreGraphics, MetalKit, IOKit, shell packaging script

---

## File Structure

- Create: `Scripts/package_app.sh`
- Create: `Resources/Info.plist`
- Create: `Sources/Utekontor/Models/MenuContentState.swift`
- Create: `Sources/Utekontor/Services/XDRAutoOffController.swift`
- Create: `Sources/Utekontor/UI/StatusIconRenderer.swift`
- Modify: `Package.swift`
- Modify: `Sources/Utekontor/AppMain.swift`
- Modify: `Sources/Utekontor/AppController.swift`
- Modify: `Sources/Utekontor/MenuBarController.swift`
- Modify: `README.md`

### Task 1: Bundle Metadata And Packaging

**Files:**
- Create: `Scripts/package_app.sh`
- Create: `Resources/Info.plist`
- Modify: `README.md`

- [ ] Add an `Info.plist` with:
  - `CFBundleIdentifier`
  - `CFBundleExecutable`
  - `CFBundleName`
  - `LSUIElement`
- [ ] Add a packaging script that:
  - runs `swift build`
  - creates `Utekontor.app/Contents/{MacOS,Resources}`
  - copies the built binary into `Contents/MacOS/Utekontor`
  - copies `Info.plist`
  - ad-hoc signs the result when `codesign` is available
- [ ] Update `README.md` with:
  - build command
  - package command
  - `open Utekontor.app`

### Task 2: App State And Timer Separation

**Files:**
- Create: `Sources/Utekontor/Models/MenuContentState.swift`
- Create: `Sources/Utekontor/Services/XDRAutoOffController.swift`
- Modify: `Sources/Utekontor/AppController.swift`

- [ ] Move the menu-facing state payload out of `MenuBarController.swift` into a dedicated model file.
- [ ] Move XDR auto-off timer scheduling and countdown formatting into `XDRAutoOffController`.
- [ ] Keep `AppController` responsible only for:
  - lifecycle hooks
  - display refresh
  - delegating state changes
  - rendering the latest state

### Task 3: Status Icon Rendering

**Files:**
- Create: `Sources/Utekontor/UI/StatusIconRenderer.swift`
- Modify: `Sources/Utekontor/MenuBarController.swift`

- [ ] Replace the direct SF Symbol assignment with a small custom template icon.
- [ ] Render distinct states:
  - idle
  - XDR enabled
  - sync enabled
  - disabled/unavailable dim state
- [ ] Keep the icon template-safe so it works in light and dark menu bars.

### Task 4: Launch Flow Verification

**Files:**
- Modify: `README.md`

- [ ] Verify `swift build` still succeeds.
- [ ] Verify the packaging script outputs `Utekontor.app`.
- [ ] Verify `open Utekontor.app` launches into the visible menu bar session.
- [ ] Document the preferred launch flow as the `.app`, not the raw binary.

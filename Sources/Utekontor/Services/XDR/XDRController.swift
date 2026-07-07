import AppKit
import CoreGraphics

private struct GammaTable {
    static let size: UInt32 = 256

    let red: [CGGammaValue]
    let green: [CGGammaValue]
    let blue: [CGGammaValue]

    static func capture(displayID: CGDirectDisplayID) -> GammaTable? {
        var red = [CGGammaValue](repeating: 0, count: Int(size))
        var green = [CGGammaValue](repeating: 0, count: Int(size))
        var blue = [CGGammaValue](repeating: 0, count: Int(size))
        var samples: UInt32 = 0
        let result = CGGetDisplayTransferByTable(displayID, size, &red, &green, &blue, &samples)
        // A short read leaves trailing zeros in the arrays; applying that later would render
        // the upper input range black. Reject anything but a complete table.
        guard result == .success, samples == size else { return nil }
        return GammaTable(red: red, green: green, blue: blue)
    }

    /// A healthy baseline is monotone and tops out near 1.0 in every channel. macOS animates
    /// sleep/wake fades by scaling the gamma tables toward zero, so a low top value means we
    /// sampled mid-fade — caching that as the baseline would render the panel permanently dark
    /// once multiplied. Checking each channel's last entry (the top of a monotone ramp) also
    /// rejects tables where a single channel is garbage.
    var isPlausibleBaseline: Bool {
        min(red.last ?? 0, green.last ?? 0, blue.last ?? 0) >= 0.5
    }

    func apply(displayID: CGDirectDisplayID, factor: Float) {
        var red = self.red.map { $0 * factor }
        var green = self.green.map { $0 * factor }
        var blue = self.blue.map { $0 * factor }
        CGSetDisplayTransferByTable(displayID, Self.size, &red, &green, &blue)
    }
}

@MainActor
final class XDRController {
    private var overlays: [CGDirectDisplayID: EDROverlayWindowController] = [:]
    private var baselines: [CGDirectDisplayID: GammaTable] = [:]
    private var hdrPollTask: Task<Void, Never>?
    private var hdrReadyDisplayIDs: Set<CGDirectDisplayID> = []
    /// Displays the current refresh wants boosted; the poll loop retries baseline capture for
    /// members that couldn't be captured yet (asleep or mid-fade at refresh time).
    private var wantedDisplayIDs: Set<CGDirectDisplayID> = []
    private var writesSuspended = false
    private(set) var isEnabled = false

    /// 0…1; 0 = no boost above baseline (1.0×), 1 = calibrated max (≈2.0× or the panel's EDR
    /// ceiling, whichever is lower).
    var level: Float = 0.7 {
        didSet {
            if isEnabled { applyGamma() }
        }
    }

    private static let hdrReadyThreshold: Float = 1.05
    /// Hard ceiling for the gamma boost. The panel's reported EDR headroom further caps this
    /// when lower. Slider above 80% is rendered as a warning since it pushes the panel past the
    /// region where banding and white-point shift stay subtle.
    private static let calibratedMaxBoost: Float = 2.0

    func enable(on screens: [NSScreen]) {
        isEnabled = true
        refresh(on: screens)
    }

    func disable() {
        isEnabled = false
        hdrPollTask?.cancel()
        hdrPollTask = nil
        hdrReadyDisplayIDs.removeAll()
        wantedDisplayIDs.removeAll()
        for (displayID, table) in baselines where CGDisplayIsAsleep(displayID) == 0 {
            // Asleep displays are skipped — writing gamma into a sleep transition is the very
            // collision this controller must avoid; the ColorSync restore below covers them.
            table.apply(displayID: displayID, factor: 1.0)
        }
        baselines.removeAll()
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    /// Stops in-flight gamma writes (the HDR poll loop fires every 100ms for up to 6s after
    /// enable) until the next `enable()` re-establishes state. Called when the display pipeline
    /// starts reconfiguring, where a concurrent gamma write risks wedging WindowServer.
    func suspendBoostWrites() {
        hdrPollTask?.cancel()
        hdrPollTask = nil
        writesSuspended = true
    }

    private func refresh(on screens: [NSScreen]) {
        guard isEnabled else { return }
        writesSuspended = false

        let supported = screens.filter { screen in
            guard let displayID = screen.displayID else { return false }
            return CGDisplayIsBuiltin(displayID) != 0 || screen.localizedName.localizedCaseInsensitiveContains("xdr") || screen.localizedName.localizedCaseInsensitiveContains("studio display")
        }

        let activeIDs = Set(supported.compactMap(\.displayID))
        wantedDisplayIDs = activeIDs
        for displayID in overlays.keys where !activeIDs.contains(displayID) {
            overlays[displayID]?.close()
            overlays.removeValue(forKey: displayID)
            baselines.removeValue(forKey: displayID)
            hdrReadyDisplayIDs.remove(displayID)
        }

        for screen in supported {
            guard let displayID = screen.displayID else { continue }
            if baselines[displayID] == nil {
                guard
                    CGDisplayIsAsleep(displayID) == 0,
                    let table = GammaTable.capture(displayID: displayID),
                    table.isPlausibleBaseline
                else {
                    // Mid-fade or asleep — don't boost this display yet; the next
                    // refresh (wake handler, display change) retries the capture.
                    continue
                }
                baselines[displayID] = table
            }
            let overlay = overlays[displayID] ?? EDROverlayWindowController(screen: screen, displayID: displayID)
            overlay.update(screen: screen)
            overlay.open()
            overlays[displayID] = overlay
        }

        startHDRPolling()
    }

    private func startHDRPolling() {
        hdrPollTask?.cancel()
        hdrPollTask = Task { @MainActor [weak self] in
            // Poll until every supported screen reaches the EDR-ready threshold; gamma is applied
            // each tick so the user sees the boost ramp in as the overlay engages.
            for _ in 0..<60 {
                guard let self, self.isEnabled, !self.writesSuspended else { return }
                var allReady = true
                for screen in NSScreen.screens {
                    guard let displayID = screen.displayID, self.wantedDisplayIDs.contains(displayID) else {
                        continue
                    }
                    // Retry baselines that couldn't be captured at refresh time (display still
                    // asleep or mid-fade) — otherwise the boost would silently stay off until
                    // the next display event even though the toggle reads as on.
                    if self.baselines[displayID] == nil {
                        guard
                            CGDisplayIsAsleep(displayID) == 0,
                            let table = GammaTable.capture(displayID: displayID),
                            table.isPlausibleBaseline
                        else {
                            allReady = false
                            continue
                        }
                        self.baselines[displayID] = table
                    }
                    let edr = Float(screen.maximumExtendedDynamicRangeColorComponentValue)
                    if edr >= Self.hdrReadyThreshold {
                        self.hdrReadyDisplayIDs.insert(displayID)
                    } else {
                        allReady = false
                    }
                }
                self.applyGamma()
                if allReady { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func applyGamma() {
        guard isEnabled, !writesSuspended else { return }
        for screen in NSScreen.screens {
            guard
                let displayID = screen.displayID,
                let table = baselines[displayID],
                CGDisplayIsAsleep(displayID) == 0
            else {
                continue
            }

            let maxEdr = Float(screen.maximumExtendedDynamicRangeColorComponentValue)
            let potentialEdr = Float(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
            let edrCeiling = max(1.0, max(maxEdr, potentialEdr))

            // Until HDR has actually engaged on this display, applying a heavy boost would just
            // wash out the panel's normal SDR range. Hold at 1.0× until the EDR overlay reports
            // headroom; the polling loop will re-call us as soon as it does.
            let isReady = hdrReadyDisplayIDs.contains(displayID)
            let cap = min(Self.calibratedMaxBoost, max(1.0, edrCeiling))
            let factor = isReady
                ? 1.0 + max(0, min(1, level)) * (cap - 1.0)
                : 1.0
            table.apply(displayID: displayID, factor: factor)
        }
    }
}

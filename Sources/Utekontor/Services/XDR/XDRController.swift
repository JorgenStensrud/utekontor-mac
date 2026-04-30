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
        guard result == .success else { return nil }
        return GammaTable(red: red, green: green, blue: blue)
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
    private(set) var isEnabled = false

    func enable(on screens: [NSScreen]) {
        isEnabled = true
        refresh(on: screens)
    }

    func disable() {
        isEnabled = false
        for (displayID, table) in baselines {
            table.apply(displayID: displayID, factor: 1.0)
        }
        baselines.removeAll()
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    private func refresh(on screens: [NSScreen]) {
        guard isEnabled else { return }

        let supported = screens.filter { screen in
            guard let displayID = screen.displayID else { return false }
            return CGDisplayIsBuiltin(displayID) != 0 || screen.localizedName.localizedCaseInsensitiveContains("xdr") || screen.localizedName.localizedCaseInsensitiveContains("studio display")
        }

        let activeIDs = Set(supported.compactMap(\.displayID))
        for displayID in overlays.keys where !activeIDs.contains(displayID) {
            overlays[displayID]?.close()
            overlays.removeValue(forKey: displayID)
            baselines.removeValue(forKey: displayID)
        }

        for screen in supported {
            guard let displayID = screen.displayID else { continue }
            if baselines[displayID] == nil {
                baselines[displayID] = GammaTable.capture(displayID: displayID)
            }
            let overlay = overlays[displayID] ?? EDROverlayWindowController(screen: screen, displayID: displayID)
            overlay.update(screen: screen)
            overlay.open()
            overlays[displayID] = overlay
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.applyGamma()
        }
    }

    private func applyGamma() {
        guard isEnabled else { return }
        for screen in NSScreen.screens {
            guard
                let displayID = screen.displayID,
                let table = baselines[displayID]
            else {
                continue
            }

            // Use both current and potential EDR ceiling so we do not leave headroom unused when
            // the system reports a conservative `maximumExtendedDynamicRangeColorComponentValue`.
            let maxEdr = Float(screen.maximumExtendedDynamicRangeColorComponentValue)
            let potentialEdr = Float(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
            let dynamicRange = max(1.0, max(maxEdr, potentialEdr))

            // Gamma lift above captured baseline. Higher `dynamicRange` → stronger boost, clamped
            // to avoid extreme banding (tunable; was 1.45 max / 0.35 slope / 1.15 floor).
            let slope: Float = 0.42
            let maxBoost: Float = 1.72
            let floorBoost: Float = 1.22
            let raw = 1.0 + (dynamicRange - 1.0) * slope
            let factor = dynamicRange > 1.02 ? min(maxBoost, raw) : floorBoost
            table.apply(displayID: displayID, factor: factor)
        }
    }
}

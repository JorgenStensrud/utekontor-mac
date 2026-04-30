import Foundation
import CoreGraphics

@MainActor
final class SyncController {
    var onBrightnessSample: ((Float) -> Void)?

    private var timer: Timer?
    private var displayID: CGDirectDisplayID?
    private var lastSample: Float?

    func start(displayID: CGDirectDisplayID) {
        if self.displayID != displayID {
            lastSample = nil
        }
        self.displayID = displayID

        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer?.tolerance = 0.1
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        displayID = nil
        lastSample = nil
    }

    private func tick() {
        guard let displayID, let value = AppleBrightness.get(displayID: displayID) else { return }
        if let lastSample, abs(lastSample - value) < 0.02 {
            return
        }
        lastSample = value
        onBrightnessSample?(value)
    }
}

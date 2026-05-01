import Foundation

@MainActor
final class ExternalBrightnessController {
    private let defaults = UserDefaults.standard
    private let ddc = Arm64DDCService()

    private(set) var currentBrightness: Float
    private(set) var isSupported = false
    private(set) var statusText = "No external display"

    private var pendingDDCValue: Float?
    private var lastDDCWriteAt: Date?
    private var debounceTask: Task<Void, Never>?
    /// Minimum gap between DDC writes. A live slider drag fires ~60 events/sec; sending each
    /// directly can overwhelm the I²C bus on some monitors and cause dropped commands. We send
    /// the leading edge immediately and coalesce trailing updates.
    private let minDDCInterval: TimeInterval = 0.05

    init() {
        let saved = defaults.object(forKey: DefaultsKey.externalBrightness.rawValue) as? Double ?? 0.7
        self.currentBrightness = Float(saved)
    }

    func bind(display: DisplaySnapshot?) {
        guard let display else {
            isSupported = false
            statusText = "No external display"
            return
        }

        isSupported = ddc.connect()
        statusText = isSupported ? "\(display.name) (DDC)" : "\(display.name) (DDC unavailable)"
    }

    func setBrightness(_ value: Float) {
        currentBrightness = max(0, min(1, value))
        defaults.set(Double(currentBrightness), forKey: DefaultsKey.externalBrightness.rawValue)
        guard isSupported else { return }
        scheduleDDCWrite(currentBrightness)
    }

    private func scheduleDDCWrite(_ value: Float) {
        let now = Date()
        let canWriteNow = lastDDCWriteAt.map { now.timeIntervalSince($0) >= minDDCInterval } ?? true
        if canWriteNow {
            lastDDCWriteAt = now
            pendingDDCValue = nil
            debounceTask?.cancel()
            debounceTask = nil
            _ = ddc.writeBrightness(normalized: value)
            return
        }

        // Coalesce: the next scheduled write picks up whatever value is current at firing time.
        pendingDDCValue = value
        guard debounceTask == nil else { return }
        let waitFor = minDDCInterval - now.timeIntervalSince(lastDDCWriteAt ?? now)
        let nanos = UInt64(max(0, waitFor) * 1_000_000_000)
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard let self else { return }
            self.debounceTask = nil
            guard let pending = self.pendingDDCValue else { return }
            self.pendingDDCValue = nil
            self.lastDDCWriteAt = Date()
            _ = self.ddc.writeBrightness(normalized: pending)
        }
    }
}

private enum DefaultsKey: String {
    case externalBrightness = "utekontor.externalBrightness"
}

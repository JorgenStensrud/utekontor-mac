import Foundation

@MainActor
final class ExternalBrightnessController {
    private let defaults = UserDefaults.standard
    private let ddc = Arm64DDCService()

    private(set) var currentBrightness: Float
    private(set) var isSupported = false
    private(set) var statusText = "No external display"

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
        _ = ddc.writeBrightness(normalized: currentBrightness)
    }
}

private enum DefaultsKey: String {
    case externalBrightness = "utekontor.externalBrightness"
}

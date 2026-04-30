import Foundation

@MainActor
final class XDRAutoOffController {
    var onUpdate: (() -> Void)?
    var onExpired: (() -> Void)?

    private var timer: Timer?
    private(set) var duration: TimeInterval?
    private(set) var deadline: Date?

    /// True while a countdown to auto-off is actively running.
    var isCountdownActive: Bool { deadline != nil }

    init(savedDuration: TimeInterval?) {
        self.duration = savedDuration
    }

    func setDuration(_ duration: TimeInterval?) {
        self.duration = duration
        if deadline != nil {
            start()
        } else {
            onUpdate?()
        }
    }

    func start() {
        guard let duration else {
            stop()
            return
        }

        deadline = Date().addingTimeInterval(duration)
        scheduleTimer()
        onUpdate?()
    }

    func ensureRunningIfNeeded(isEnabled: Bool) {
        guard isEnabled, duration != nil else { return }
        if timer == nil {
            start()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        onUpdate?()
    }

    func statusLabel(isEnabled: Bool) -> String {
        guard isEnabled else {
            if let duration {
                return "Auto-off preset: \(Self.formatDuration(duration))"
            }
            return "Auto-off: Off"
        }

        guard let deadline else {
            if let duration {
                return "Auto-off preset: \(Self.formatDuration(duration))"
            }
            return "Auto-off: Off"
        }

        let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.down)))
        return "Time left: \(Self.formatCountdown(seconds: remaining))"
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer?.tolerance = 0.2
    }

    private func tick() {
        guard let deadline else {
            stop()
            return
        }

        if deadline <= Date() {
            timer?.invalidate()
            timer = nil
            self.deadline = nil
            onExpired?()
            return
        }

        onUpdate?()
    }

    /// Digital-style countdown (e.g. `9:30` = nine minutes thirty seconds left).
    private static func formatCountdown(seconds: Int) -> String {
        let totalMinutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", totalMinutes, secs)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        switch minutes {
        case 60:
            return "1 hour"
        case 120:
            return "2 hours"
        case 90:
            return "90 min"
        default:
            return "\(minutes) min"
        }
    }
}

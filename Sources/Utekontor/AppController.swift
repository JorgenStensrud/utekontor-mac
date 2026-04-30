import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private let discovery = DisplayDiscovery()
    private let xdrController = XDRController()
    private let externalBrightnessController = ExternalBrightnessController()
    private let syncController = SyncController()
    private let xdrAutoOffController: XDRAutoOffController

    private lazy var menuBarController = MenuBarController(
        onToggleXDR: { [weak self] in self?.toggleXDR() },
        onInternalBrightnessChanged: { [weak self] value in self?.setInternalBrightness(value) },
        onExternalBrightnessChanged: { [weak self] value in self?.setExternalBrightness(value) },
        onToggleSync: { [weak self] in self?.toggleSync() },
        onSelectXDRAutoOffDuration: { [weak self] duration in self?.setXDRAutoOffDuration(duration) },
        onQuit: { NSApp.terminate(nil) }
    )

    private var displays: [DisplaySnapshot] = []
    private var internalDisplay: DisplaySnapshot?
    private var externalDisplay: DisplaySnapshot?
    private var internalBrightness: Float = 0.5

    private var xdrEnabled: Bool {
        didSet {
            defaults.set(xdrEnabled, forKey: DefaultsKey.xdrEnabled.rawValue)
        }
    }

    private var syncEnabled: Bool {
        didSet {
            defaults.set(syncEnabled, forKey: DefaultsKey.syncEnabled.rawValue)
        }
    }

    private var xdrAutoOffDuration: TimeInterval? {
        didSet {
            defaults.set(xdrAutoOffDuration ?? 0, forKey: DefaultsKey.xdrAutoOffDuration.rawValue)
        }
    }

    override init() {
        self.xdrEnabled = defaults.bool(forKey: DefaultsKey.xdrEnabled.rawValue)
        self.syncEnabled = defaults.bool(forKey: DefaultsKey.syncEnabled.rawValue)
        let savedDuration = defaults.double(forKey: DefaultsKey.xdrAutoOffDuration.rawValue)
        let initialDuration = savedDuration > 0 ? savedDuration : nil
        self.xdrAutoOffDuration = initialDuration
        self.xdrAutoOffController = XDRAutoOffController(savedDuration: initialDuration)
        super.init()
        syncController.onBrightnessSample = { [weak self] value in
            self?.applySyncedBrightness(value)
        }
        xdrAutoOffController.onUpdate = { [weak self] in
            self?.refreshMenuOnly()
        }
        xdrAutoOffController.onExpired = { [weak self] in
            guard let self else { return }
            self.xdrEnabled = false
            self.refreshDisplayState()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.install()
        wireLifecycleObservers()
        refreshDisplayState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        syncController.stop()
        xdrAutoOffController.stop()
        xdrController.disable()
    }

    private func wireLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc
    private func handleDisplayChange() {
        refreshDisplayState()
    }

    func refreshDisplayState() {
        displays = discovery.discoverDisplays()
        internalDisplay = displays.first(where: \.isBuiltIn)
        externalDisplay = displays.first(where: { !$0.isBuiltIn })
        externalBrightnessController.bind(display: externalDisplay)
        if let internalDisplay, let currentBrightness = AppleBrightness.get(displayID: internalDisplay.id) {
            internalBrightness = currentBrightness
        }

        if xdrEnabled {
            xdrController.enable(on: NSScreen.screens)
            xdrAutoOffController.ensureRunningIfNeeded(isEnabled: true)
        } else {
            xdrController.disable()
        }

        if syncEnabled, let internalDisplay {
            syncController.start(displayID: internalDisplay.id)
        } else {
            syncController.stop()
        }

        menuBarController.render(currentMenuState())
    }

    private func toggleXDR() {
        xdrEnabled.toggle()
        if xdrEnabled {
            xdrAutoOffController.start()
        } else {
            xdrAutoOffController.stop()
        }
        refreshDisplayState()
    }

    private func setInternalBrightness(_ value: Double) {
        guard let internalDisplay else { return }
        internalBrightness = Float(value)
        _ = AppleBrightness.set(displayID: internalDisplay.id, value: internalBrightness)
        refreshMenuOnly()
    }

    private func setExternalBrightness(_ value: Double) {
        externalBrightnessController.setBrightness(Float(value))
        refreshMenuOnly()
    }

    private func toggleSync() {
        syncEnabled.toggle()
        refreshDisplayState()
    }

    private func applySyncedBrightness(_ value: Float) {
        guard syncEnabled else { return }
        externalBrightnessController.setBrightness(value)
        refreshMenuOnly()
    }

    private func setXDRAutoOffDuration(_ duration: TimeInterval?) {
        xdrAutoOffDuration = duration
        xdrAutoOffController.setDuration(duration)
        if xdrEnabled, duration != nil {
            xdrAutoOffController.start()
        }
        refreshMenuOnly()
    }

    private func refreshMenuOnly() {
        menuBarController.render(
            currentMenuState()
        )
    }

    private func currentMenuState() -> MenuContentState {
        MenuContentState(
            internalLabel: internalDisplay?.name ?? "No internal display",
            externalLabel: externalBrightnessController.statusText,
            xdrEnabled: xdrEnabled,
            syncEnabled: syncEnabled,
            internalBrightness: Double(internalBrightness),
            internalBrightnessEnabled: internalDisplay != nil,
            externalBrightness: Double(externalBrightnessController.currentBrightness),
            externalBrightnessEnabled: externalBrightnessController.isSupported,
            xdrAutoOffDuration: xdrAutoOffDuration,
            xdrAutoOffLabel: xdrAutoOffController.statusLabel(isEnabled: xdrEnabled),
            xdrAutoOffCountdownActive: xdrAutoOffController.isCountdownActive
        )
    }
}

private enum DefaultsKey: String {
    case xdrEnabled = "utekontor.xdrEnabled"
    case syncEnabled = "utekontor.syncEnabled"
    case xdrAutoOffDuration = "utekontor.xdrAutoOffDuration"
}

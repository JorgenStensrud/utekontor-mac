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
        onXDRLevelChanged: { [weak self] value in self?.setXDRLevel(value) },
        onToggleSync: { [weak self] in self?.toggleSync() },
        onSelectXDRAutoOffDuration: { [weak self] duration in self?.setXDRAutoOffDuration(duration) },
        onPopoverWillShow: { [weak self] in self?.startBrightnessPolling() },
        onPopoverDidClose: { [weak self] in self?.stopBrightnessPolling() },
        onShowAbout: { [weak self] in self?.showAboutAlert() },
        onQuit: { NSApp.terminate(nil) }
    )

    private var displays: [DisplaySnapshot] = []
    private var internalDisplay: DisplaySnapshot?
    private var externalDisplay: DisplaySnapshot?
    private var internalBrightness: Float = 0.5
    private var brightnessPollTimer: Timer?
    private var pendingWakeRefreshTask: Task<Void, Never>?
    private var pendingDisplayChangeTask: Task<Void, Never>?

    /// macOS animates the wake fade-in through the display gamma tables. Writing gamma during
    /// that window can wedge WindowServer's fade state machine — the built-in panel then renders
    /// black (backlight on) until a display pipeline reinit, surviving even this app's exit.
    /// Wait for the fade to complete before touching gamma again.
    private static let wakeRefreshDelay: TimeInterval = 4
    /// Display reconfiguration fires notification bursts; coalesce before re-applying gamma.
    private static let displayChangeDebounce: TimeInterval = 1.5

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

    private var xdrLevel: Double {
        didSet {
            defaults.set(xdrLevel, forKey: DefaultsKey.xdrLevel.rawValue)
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
        let savedXDRLevel = defaults.object(forKey: DefaultsKey.xdrLevel.rawValue) as? Double
        self.xdrLevel = savedXDRLevel ?? 0.7
        let savedDuration = defaults.double(forKey: DefaultsKey.xdrAutoOffDuration.rawValue)
        let initialDuration = savedDuration > 0 ? savedDuration : nil
        self.xdrAutoOffDuration = initialDuration
        self.xdrAutoOffController = XDRAutoOffController(savedDuration: initialDuration)
        super.init()
        xdrController.level = Float(self.xdrLevel)
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
        // A previous instance that crashed with the boost active can leave its gamma tables
        // behind; start from the profile's clean state before capturing any baseline.
        CGDisplayRestoreColorSyncSettings()
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
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
    }

    @objc
    private func handleDisplayChange() {
        pendingDisplayChangeTask?.cancel()
        pendingDisplayChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.displayChangeDebounce * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshDisplayState()
        }
    }

    /// Tear down the gamma boost and overlays before the displays go dark, so the system's own
    /// sleep/wake gamma fades never overlap with ours. `xdrEnabled` is left untouched — the wake
    /// handler brings the boost back once the fade has settled.
    @objc
    private func handleWillSleep() {
        pendingWakeRefreshTask?.cancel()
        pendingDisplayChangeTask?.cancel()
        xdrController.disable()
    }

    @objc
    private func handleScreensDidWake() {
        pendingWakeRefreshTask?.cancel()
        pendingWakeRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.wakeRefreshDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshDisplayState()
        }
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
        let clamped = Float(max(0, min(1, value)))
        internalBrightness = clamped
        _ = AppleBrightness.set(displayID: internalDisplay.id, value: clamped)
        if syncEnabled {
            externalBrightnessController.setBrightness(clamped)
        }
        refreshMenuOnly()
    }

    private func setExternalBrightness(_ value: Double) {
        let clamped = Float(max(0, min(1, value)))
        externalBrightnessController.setBrightness(clamped)
        if syncEnabled, let internalDisplay {
            internalBrightness = clamped
            _ = AppleBrightness.set(displayID: internalDisplay.id, value: clamped)
        }
        refreshMenuOnly()
    }

    private func setXDRLevel(_ value: Double) {
        xdrLevel = max(0, min(1, value))
        xdrController.level = Float(xdrLevel)
        refreshMenuOnly()
    }

    private func startBrightnessPolling() {
        sampleInternalBrightnessAndRender()
        brightnessPollTimer?.invalidate()
        brightnessPollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleInternalBrightnessAndRender()
            }
        }
        brightnessPollTimer?.tolerance = 0.05
    }

    private func stopBrightnessPolling() {
        brightnessPollTimer?.invalidate()
        brightnessPollTimer = nil
    }

    private func sampleInternalBrightnessAndRender() {
        guard
            let internalDisplay,
            let value = AppleBrightness.get(displayID: internalDisplay.id)
        else { return }
        if abs(internalBrightness - value) < 0.005 { return }
        internalBrightness = value
        refreshMenuOnly()
    }

    private func showAboutAlert() {
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let alert = NSAlert()
        alert.messageText = "Om Utekontor \(appVersion)"
        alert.informativeText = """
            Utekontor er en menylinje-app for lysstyrke, XDR-boost og ekstern skjerm via DDC.

            Er det trygt for skjermen min?
            Ja. macOS har fortsatt full kontroll over skjerm-maskinvaren og throttler hvis det skulle bli \
            for varmt — du kan ikke skade panelet med Utekontor. Vi bruker HDR-API-ene som allerede er \
            innebygd i din Mac. Apple har designet disse skjermene for å håndtere XDR-lysstyrke.

            Det du vil merke ved høy boost:
            • Mer varme (vifter kan slå inn)
            • Kortere batteritid
            • Hvitbalansen kan skifte litt (lett rosa eller gul vri)
            • Banding i gradienter over ~80%
            • Sort blir noe lyssere (kontrasttap)

            Disse effektene er reversible — slå av XDR, og alt er tilbake. Sliderverdier over 80% er \
            markert i rødt fordi det er der trade-offs blir mer tydelige. Auto-off-timeren under XDR \
            hjelper deg å huske å slå av når du går inn igjen.

            Lisens: MIT. Levert «AS IS», uten garanti. Forfatter og bidragsytere er ikke ansvarlige \
            for direkte eller indirekte skade som følge av bruk. Bygget med AI.

            Kildekode og oppdateringer: github.com/JorgenStensrud/utekontor-mac
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Vis MIT-lisens")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/JorgenStensrud/utekontor-mac/blob/main/LICENSE") {
                NSWorkspace.shared.open(url)
            }
        }
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
            xdrLevel: xdrLevel,
            xdrAutoOffDuration: xdrAutoOffDuration,
            xdrAutoOffLabel: xdrAutoOffController.statusLabel(isEnabled: xdrEnabled),
            xdrAutoOffCountdownActive: xdrAutoOffController.isCountdownActive
        )
    }
}

private enum DefaultsKey: String {
    case xdrEnabled = "utekontor.xdrEnabled"
    case syncEnabled = "utekontor.syncEnabled"
    case xdrLevel = "utekontor.xdrLevel"
    case xdrAutoOffDuration = "utekontor.xdrAutoOffDuration"
}

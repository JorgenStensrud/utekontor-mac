import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let onToggleXDR: () -> Void
    private let onInternalBrightnessChanged: (Double) -> Void
    private let onExternalBrightnessChanged: (Double) -> Void
    private let onToggleSync: () -> Void
    private let onSelectXDRAutoOffDuration: (TimeInterval?) -> Void
    private let onQuit: () -> Void

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var hostingController: NSHostingController<MenuPopoverView>?
    private var currentState = MenuContentState(
        internalLabel: "No internal display",
        externalLabel: "No external display",
        xdrEnabled: false,
        syncEnabled: false,
        internalBrightness: 0.5,
        internalBrightnessEnabled: false,
        externalBrightness: 0.7,
        externalBrightnessEnabled: false,
        xdrAutoOffDuration: nil,
        xdrAutoOffLabel: "Auto-off: Off",
        xdrAutoOffCountdownActive: false
    )

    init(
        onToggleXDR: @escaping () -> Void,
        onInternalBrightnessChanged: @escaping (Double) -> Void,
        onExternalBrightnessChanged: @escaping (Double) -> Void,
        onToggleSync: @escaping () -> Void,
        onSelectXDRAutoOffDuration: @escaping (TimeInterval?) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggleXDR = onToggleXDR
        self.onInternalBrightnessChanged = onInternalBrightnessChanged
        self.onExternalBrightnessChanged = onExternalBrightnessChanged
        self.onToggleSync = onToggleSync
        self.onSelectXDRAutoOffDuration = onSelectXDRAutoOffDuration
        self.onQuit = onQuit
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = StatusIconRenderer.makeIcon(xdrEnabled: false, syncEnabled: false, externalAvailable: false)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        // Borderless menubar popover (no arrow); matches system extras.
        popover.setValue(true, forKey: "shouldHideAnchor")
        let view = makePopoverView(state: currentState)
        let hostingController = NSHostingController(rootView: view)
        self.hostingController = hostingController
        popover.contentViewController = hostingController
    }

    func render(_ state: MenuContentState) {
        currentState = state
        hostingController?.rootView = makePopoverView(state: state)
        if popover.isShown {
            preparePopoverContentSize()
        }
        statusItem.button?.image = StatusIconRenderer.makeIcon(
            xdrEnabled: state.xdrEnabled,
            syncEnabled: state.syncEnabled,
            externalAvailable: state.externalBrightnessEnabled
        )
        statusItem.button?.image?.isTemplate = true
    }

    private func makePopoverView(state: MenuContentState) -> MenuPopoverView {
        MenuPopoverView(
            state: state,
            onToggleXDR: onToggleXDR,
            onInternalBrightnessChanged: onInternalBrightnessChanged,
            onExternalBrightnessChanged: onExternalBrightnessChanged,
            onToggleSync: onToggleSync,
            onSelectXDRAutoOffDuration: onSelectXDRAutoOffDuration,
            onQuit: onQuit
        )
    }

    @objc
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            preparePopoverContentSize()
            sender.window?.layoutIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    /// SwiftUI hosting views often report `.zero` size until layout; without this, `NSPopover`
    /// can anchor incorrectly (e.g. flush to the top of the screen).
    private func preparePopoverContentSize() {
        guard let view = hostingController?.view else {
            popover.contentSize = NSSize(width: 320, height: 440)
            return
        }
        view.layoutSubtreeIfNeeded()
        let fit = view.fittingSize
        let width = fit.width > 80 ? fit.width : 320
        let height = fit.height > 80 ? fit.height : 440
        popover.contentSize = NSSize(width: width, height: height)
    }
}

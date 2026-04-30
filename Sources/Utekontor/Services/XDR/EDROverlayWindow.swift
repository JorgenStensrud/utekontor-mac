import AppKit

final class EDROverlayWindowController: NSWindowController {
    let displayID: CGDirectDisplayID

    init(screen: NSScreen, displayID: CGDirectDisplayID) {
        self.displayID = displayID
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        super.init(window: window)
        update(screen: screen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func open() {
        window?.orderFrontRegardless()
    }

    func update(screen: NSScreen) {
        let origin = CGPoint(x: screen.frame.minX, y: screen.frame.maxY - 1)
        window?.setFrameOrigin(origin)
        window?.contentView = EDROverlayView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }
}

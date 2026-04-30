import AppKit

enum StatusIconRenderer {
    /// Sun symbol for the menu bar; filled when XDR is active.
    static func makeIcon(xdrEnabled: Bool, syncEnabled: Bool, externalAvailable: Bool) -> NSImage {
        _ = syncEnabled
        let name = xdrEnabled ? "sun.max.fill" : "sun.max"
        let weight: NSFont.Weight = externalAvailable ? .medium : .regular
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: weight)
        let base =
            NSImage(systemSymbolName: name, accessibilityDescription: "Utekontor")
            ?? NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Utekontor")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }
}

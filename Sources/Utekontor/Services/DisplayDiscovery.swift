import AppKit
import CoreGraphics

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

@MainActor
struct DisplayDiscovery {
    func discoverDisplays() -> [DisplaySnapshot] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            return DisplaySnapshot(
                id: id,
                name: screen.localizedName,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                vendorID: CGDisplayVendorNumber(id),
                modelID: CGDisplayModelNumber(id),
                serialNumber: CGDisplaySerialNumber(id),
                isLikelyXDR: isLikelyXDR(screen: screen, id: id)
            )
        }
    }

    private func isLikelyXDR(screen: NSScreen, id: CGDirectDisplayID) -> Bool {
        if CGDisplayIsBuiltin(id) != 0 {
            return true
        }

        let lowered = screen.localizedName.lowercased()
        return lowered.contains("xdr") || lowered.contains("studio display")
    }
}

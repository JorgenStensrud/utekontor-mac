import AppKit
import CoreGraphics

struct DisplaySnapshot: Equatable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let vendorID: UInt32
    let modelID: UInt32
    let serialNumber: UInt32
    let isLikelyXDR: Bool
}

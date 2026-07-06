import CoreGraphics

struct DisplaySnapshot: Equatable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
}

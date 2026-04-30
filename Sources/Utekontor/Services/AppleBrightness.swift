import CoreGraphics

@MainActor
enum AppleBrightness {
    static func get(displayID: CGDirectDisplayID) -> Float? {
        guard let function = PrivateDisplayAPIs.getBrightness else {
            return nil
        }
        var value: Float = 0
        let result = function(displayID, &value)
        return result == 0 ? value : nil
    }

    @discardableResult
    static func set(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let function = PrivateDisplayAPIs.setBrightness else {
            return false
        }
        return function(displayID, max(0, min(1, value))) == 0
    }
}

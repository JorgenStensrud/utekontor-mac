import Foundation

struct MenuContentState {
    let internalLabel: String
    let externalLabel: String
    let xdrEnabled: Bool
    let syncEnabled: Bool
    let internalBrightness: Double
    let internalBrightnessEnabled: Bool
    let externalBrightness: Double
    let externalBrightnessEnabled: Bool
    let xdrLevel: Double
    let xdrAutoOffDuration: TimeInterval?
    let xdrAutoOffLabel: String
    let xdrAutoOffCountdownActive: Bool
}

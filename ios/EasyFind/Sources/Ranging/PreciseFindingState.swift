import Foundation

enum FindingPresentationState: String {
    case bluetoothUnavailable
    case scanning
    case ready
    case preparing
    case finding
    case directionLost
    case nearby
    case suspended
    case failure

    static func fromString(_ s: String) -> FindingPresentationState {
        return FindingPresentationState(rawValue: s) ?? .scanning
    }
}

struct PreciseFindingState {
    var presentationState: FindingPresentationState = .scanning
    var distance: Double?
    var horizontalAngle: Double?
    var elevationAngle: Double?
    var alignmentProgress: Double = 0.0
    var proximityProgress: Double = 0.0
    var connectedDeviceName: String?
    var errorMessage: String?
    var isSoundPlaying: Bool = false
    var directionEverAcquired: Bool = false
    var nearbyAcquired: Bool = false

    var greenProgress: Double {
        let nearbyBoost = presentationState == .nearby ? 0.18 : 0.0
        return (alignmentProgress * 0.82 + proximityProgress * 0.18 + nearbyBoost).clamped(to: 0...1)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

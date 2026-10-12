import Foundation

/// Boolean debounce with asymmetric delays.
/// Rise (false→true): immediate. Fall (true→false): waits for fallDelay.
final class DebounceFilter {
    private let riseDelay: TimeInterval
    private let fallDelay: TimeInterval
    private var output: Bool = false
    private var edgeTime: Date?

    init(riseDelay: TimeInterval = 0, fallDelay: TimeInterval) {
        self.riseDelay = riseDelay
        self.fallDelay = fallDelay
    }

    func update(_ input: Bool) -> Bool {
        let now = Date()

        if input == output {
            edgeTime = nil
            return output
        }

        if edgeTime == nil {
            edgeTime = now
        }

        let elapsed = now.timeIntervalSince(edgeTime!)
        let required = input ? riseDelay : fallDelay

        if elapsed >= required {
            output = input
            edgeTime = nil
        }

        return output
    }

    var value: Bool { output }

    func reset() {
        output = false
        edgeTime = nil
    }
}

/// Hysteresis filter for numeric signals. Prevents threshold oscillation.
/// Enter when value ≤ enterThreshold. Exit when value > exitThreshold.
final class HysteresisFilter {
    private let enterThreshold: Double
    private let exitThreshold: Double
    private var active: Bool = false

    init(enterThreshold: Double, exitThreshold: Double) {
        precondition(exitThreshold > enterThreshold,
                     "exitThreshold (\(exitThreshold)) must be > enterThreshold (\(enterThreshold))")
        self.enterThreshold = enterThreshold
        self.exitThreshold = exitThreshold
    }

    func update(_ value: Double) -> Bool {
        if !active && value <= enterThreshold {
            active = true
        } else if active && value > exitThreshold {
            active = false
        }
        return active
    }

    var isActive: Bool { active }

    func reset() {
        active = false
    }
}

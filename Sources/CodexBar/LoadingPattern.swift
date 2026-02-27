import Foundation

enum LoadingPattern: String, CaseIterable, Identifiable {
    case knightRider
    case cylon
    case outsideIn
    case race
    case pulse
    case unbraid

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .knightRider: return "Knight Rider"
        case .cylon: return "Cylon"
        case .outsideIn: return "Outside-In"
        case .race: return "Race"
        case .pulse: return "Pulse"
        case .unbraid: return "Unbraid (logo → bars)"
        }
    }

    /// Secondary offset so the lower bar moves differently.
    var secondaryOffset: Double {
        switch self {
        case .knightRider: return Double.pi
        case .cylon: return Double.pi / 2
        case .outsideIn: return Double.pi
        case .race: return Double.pi / 3
        case .pulse: return Double.pi / 2
        case .unbraid: return Double.pi / 2
        }
    }

    func value(phase: Double) -> Double {
        let v: Double
        switch self {
        case .knightRider:
            v = 0.5 + 0.5 * sin(phase) // ping-pong
        case .cylon:
            let t = phase.truncatingRemainder(dividingBy: Double.pi * 2) / (Double.pi * 2)
            v = t // sawtooth 0→1
        case .outsideIn:
            v = abs(cos(phase)) // high at edges, dip center
        case .race:
            let t = (phase * 1.2).truncatingRemainder(dividingBy: Double.pi * 2) / (Double.pi * 2)
            v = t
        case .pulse:
            v = 0.4 + 0.6 * (0.5 + 0.5 * sin(phase)) // 40–100%
        case .unbraid:
            v = 0.5 + 0.5 * sin(phase) // smooth 0→1 for morph
        }
        return max(0, min(v * 100, 100))
    }
}

extension Notification.Name {
    static let codexbarDebugReplayAllAnimations = Notification.Name("codexbarDebugReplayAllAnimations")
}

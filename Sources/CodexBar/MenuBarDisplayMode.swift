import Foundation

/// Controls what the menu bar displays when brand icon mode is enabled.
enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case percent
    case pace
    case both

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .percent: return "Percent"
        case .pace: return "Pace"
        case .both: return "Both"
        }
    }

    var description: String {
        switch self {
        case .percent: return "Show remaining/used percentage (e.g. 45%)"
        case .pace: return "Show pace indicator (e.g. +5%)"
        case .both: return "Show both percentage and pace (e.g. 45% · +5%)"
        }
    }
}

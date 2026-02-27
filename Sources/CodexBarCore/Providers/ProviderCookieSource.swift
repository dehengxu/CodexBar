import Foundation

public enum ProviderCookieSource: String, CaseIterable, Identifiable, Sendable, Codable {
    case auto
    case manual
    case off

    public var id: String {
        self.rawValue
    }

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        case .off: return "Off"
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .off: return false
        case .auto, .manual: return true
        }
    }
}

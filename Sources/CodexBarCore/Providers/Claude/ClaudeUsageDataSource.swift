import Foundation

public enum ClaudeUsageDataSource: String, CaseIterable, Identifiable, Sendable {
    case auto
    case oauth
    case web
    case cli

    public var id: String {
        self.rawValue
    }

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .oauth: return "OAuth API"
        case .web: return "Web API (cookies)"
        case .cli: return "CLI (PTY)"
        }
    }

    public var sourceLabel: String {
        switch self {
        case .auto:
            return "auto"
        case .oauth:
            return "oauth"
        case .web:
            return "web"
        case .cli:
            return "cli"
        }
    }
}

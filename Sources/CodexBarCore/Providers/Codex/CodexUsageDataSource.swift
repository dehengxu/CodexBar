import Foundation

public enum CodexUsageDataSource: String, CaseIterable, Identifiable, Sendable {
    case auto
    case oauth
    case cli

    public var id: String {
        self.rawValue
    }

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .oauth: return "OAuth API"
        case .cli: return "CLI (RPC/PTY)"
        }
    }

    public var sourceLabel: String {
        switch self {
        case .auto:
            return "auto"
        case .oauth:
            return "oauth"
        case .cli:
            return "cli"
        }
    }
}

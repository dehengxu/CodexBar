import Foundation

public struct ArkSettingsReader: Sendable {
    private static let log = CodexBarLog.logger(LogCategories.arkSettings)

    public static let apiTokenKey = "ARK_API_KEY"
    public static let apiHostKey = "ARK_API_HOST"
    public static let quotaURLKey = "ARK_QUOTA_URL"

    public static func apiToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let token = self.cleaned(environment[apiTokenKey]) { return token }
        return nil
    }

    public static func apiHost(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[self.apiHostKey])
    }

    public static func quotaURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL?
    {
        guard let raw = self.cleaned(environment[quotaURLKey]) else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value.removeFirst()
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

public enum ArkSettingsError: LocalizedError, Sendable {
    case missingToken

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "ARK API token not found. Set apiKey in ~/.codexbar/config.json or ARK_API_KEY."
        }
    }
}

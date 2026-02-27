import Foundation

public enum KimiAPIError: LocalizedError, Sendable, Equatable {
    case missingToken
    case invalidToken
    case invalidRequest(String)
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Kimi auth token is missing. Please add your JWT token from the Kimi console."
        case .invalidToken:
            return "Kimi auth token is invalid or expired. Please refresh your token."
        case let .invalidRequest(message):
            return "Invalid request: \(message)"
        case let .networkError(message):
            return "Kimi network error: \(message)"
        case let .apiError(message):
            return "Kimi API error: \(message)"
        case let .parseFailed(message):
            return "Failed to parse Kimi usage data: \(message)"
        }
    }
}

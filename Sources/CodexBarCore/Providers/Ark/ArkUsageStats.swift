import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// ARK usage limit types from the API
public enum ArkLimitType: String, Sendable {
    case session = "Session"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

/// ARK usage response structure
public struct ArkUsageSnapshot: Sendable {
    public let sessionLimit: ArkLimitEntry?
    public let weeklyLimit: ArkLimitEntry?
    public let monthlyLimit: ArkLimitEntry?
    public let planName: String?
    public let updatedAt: Date

    public init(
        sessionLimit: ArkLimitEntry?,
        weeklyLimit: ArkLimitEntry?,
        monthlyLimit: ArkLimitEntry?,
        planName: String?,
        updatedAt: Date)
    {
        self.sessionLimit = sessionLimit
        self.weeklyLimit = weeklyLimit
        self.monthlyLimit = monthlyLimit
        self.planName = planName
        self.updatedAt = updatedAt
    }

    /// Returns true if this snapshot contains valid ARK data
    public var isValid: Bool {
        self.sessionLimit != nil || self.weeklyLimit != nil || self.monthlyLimit != nil
    }
}

extension ArkUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primary = self.sessionLimit.map { Self.rateWindow(for: $0) }
        let secondary = self.weeklyLimit.map { Self.rateWindow(for: $0) }
        let tertiary = self.monthlyLimit.map { Self.rateWindow(for: $0) }

        let planName = self.planName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginMethod = (planName?.isEmpty ?? true) ? nil : planName
        let identity = ProviderIdentitySnapshot(
            providerID: .ark,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: loginMethod)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: identity)
    }

    private static func rateWindow(for limit: ArkLimitEntry) -> RateWindow {
        RateWindow(
            usedPercent: limit.usedPercent,
            windowMinutes: nil,
            resetsAt: limit.nextResetTime,
            resetDescription: limit.level)
    }
}

/// A single limit entry from the ARK API
public struct ArkLimitEntry: Sendable {
    public let level: String
    public let usedPercent: Double
    public let nextResetTime: Date?

    public init(level: String, usedPercent: Double, nextResetTime: Date?) {
        self.level = level
        self.usedPercent = usedPercent
        self.nextResetTime = nextResetTime
    }
}

/// ARK quota API response
private struct ArkQuotaResponse: Decodable {
    let Resultt: ArkQuotaResult?
}

private struct ArkQuotaResult: Decodable {
    let QuotaUsage: [ArkQuotaUsageItem]?
}

private struct ArkQuotaUsageItem: Decodable {
    let Level: String?
    let Percent: Double?
    let ResetTimestamp: Int64?

    func toLimitEntry() -> ArkLimitEntry? {
        guard let level = self.Level else { return nil }
        let percent = self.Percent ?? 0
        let resetTime = self.ResetTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        return ArkLimitEntry(level: level, usedPercent: percent, nextResetTime: resetTime)
    }
}

/// Fetches usage stats from the ARK API
public struct ArkUsageFetcher: Sendable {
    private static let log = CodexBarLog.logger(LogCategories.arkUsage)

    /// Default ARK host
    private static let defaultHost = "console.volcengine.com"

    /// Path for ARK quota API
    private static let quotaAPIPath = "api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage"

    /// Resolves the quota URL using (in order):
    /// 1) `ARK_QUOTA_URL` environment override (full URL).
    /// 2) `ARK_API_HOST` environment override (host/base URL).
    /// 3) Default ARK host.
    public static func resolveQuotaURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL
    {
        if let override = ArkSettingsReader.quotaURL(environment: environment) {
            return override
        }
        let host = ArkSettingsReader.apiHost(environment: environment) ?? Self.defaultHost
        return URL(string: "https://\(host)/\(Self.quotaAPIPath)")!
    }

    /// Fetches usage stats from ARK using the provided API key
    public static func fetchUsage(
        apiKey: String,
        environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> ArkUsageSnapshot
    {
        guard !apiKey.isEmpty else {
            throw ArkUsageError.invalidCredentials
        }

        let quotaURL = self.resolveQuotaURL(environment: environment)

        var request = URLRequest(url: quotaURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-ca-key")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArkUsageError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("ARK API returned \(httpResponse.statusCode): \(errorMessage)")
            throw ArkUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        guard !data.isEmpty else {
            Self.log.error("ARK API returned empty body (HTTP 200)")
            throw ArkUsageError.parseFailed("Empty response body")
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("ARK API response: \(jsonString)")
        }

        do {
            return try Self.parseUsageSnapshot(from: data)
        } catch let error as DecodingError {
            Self.log.error("ARK JSON decoding error: \(error.localizedDescription)")
            throw ArkUsageError.parseFailed(error.localizedDescription)
        } catch let error as ArkUsageError {
            throw error
        } catch {
            Self.log.error("ARK parsing error: \(error.localizedDescription)")
            throw ArkUsageError.parseFailed(error.localizedDescription)
        }
    }

    static func parseUsageSnapshot(from data: Data) throws -> ArkUsageSnapshot {
        guard !data.isEmpty else {
            throw ArkUsageError.parseFailed("Empty response body")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ArkQuotaResponse.self, from: data)

        guard let result = apiResponse.Resultt else {
            throw ArkUsageError.parseFailed("Missing Result")
        }

        var sessionLimit: ArkLimitEntry?
        var weeklyLimit: ArkLimitEntry?
        var monthlyLimit: ArkLimitEntry?

        if let quotaItems = result.QuotaUsage {
            for item in quotaItems {
                guard let entry = item.toLimitEntry() else { continue }
                let level = entry.level.lowercased()
                if level.contains("session") {
                    sessionLimit = entry
                } else if level.contains("week") {
                    weeklyLimit = entry
                } else if level.contains("month") {
                    monthlyLimit = entry
                }
            }
        }

        return ArkUsageSnapshot(
            sessionLimit: sessionLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            planName: nil,
            updatedAt: Date())
    }
    /// Generates a curl command for testing the ARK API
    public static func curlCommand(
        cookieHeader: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String
    {
        let url = Self.resolveQuotaURL(environment: environment)
        var lines: [String] = []

        lines.append("curl '\(url.absoluteString)' \\")

        lines.append("  -H 'accept: application/json' \\")
        lines.append("  -H 'content-type: application/json' \\")

        if let cookie = cookieHeader, !cookie.isEmpty {
            let escapedCookie = cookie.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("  -b '\(escapedCookie)' \\")
        }

        lines.append("  --data-raw '{}'")

        return lines.joined(separator: "\n")
    }
}

/// Errors that can occur during ARK usage fetching
public enum ArkUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid ARK API credentials"
        case let .networkError(message):
            return "ARK network error: \(message)"
        case let .apiError(message):
            return "ARK API error: \(message)"
        case let .parseFailed(message):
            return "Failed to parse ARK response: \(message)"
        }
    }
}

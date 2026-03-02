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
        // Use API provided reset time if it's in the future, otherwise calculate next reset time
        let resetsAt = Self.resolveResetTime(limit.nextResetTime, level: limit.level)
        return RateWindow(
            usedPercent: limit.usedPercent,
            windowMinutes: Self.windowMinutes(for: limit.level),
            resetsAt: resetsAt,
            resetDescription: limit.level)
    }

    /// Resolve reset time: use API provided time if in future, otherwise calculate next reset time
    private static func resolveResetTime(_ apiResetTime: Date?, level: String) -> Date? {
        let now = Date()

        // If API provides a future reset time, use it
        if let apiTime = apiResetTime, apiTime > now {
            return apiTime
        }

        // If API provides a past reset time (expired), calculate next reset time
        if let apiTime = apiResetTime, apiTime <= now {
            return Self.calculateNextResetTime(for: level, from: apiTime)
        }

        // If no API reset time, calculate from now
        return Self.calculateNextResetTime(for: level, from: now)
    }

    /// Calculate next reset time based on limit type
    /// For Session: adds 5 hours to the base date (assuming it was the last reset time)
    /// For Weekly/Monthly: finds next Sunday/Month-end after the base date
    private static func calculateNextResetTime(for level: String, from baseDate: Date) -> Date? {
        let calendar = Calendar.current
        let levelLower = level.lowercased()

        if levelLower.contains("session") {
            // Session resets 5 hours after the base date
            return calendar.date(byAdding: .hour, value: 5, to: baseDate)
        } else if levelLower.contains("week") {
            // Weekly resets at next Sunday 23:59:59 after the base date
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)
            components.weekday = 1 // Sunday
            components.hour = 23
            components.minute = 59
            components.second = 59

            guard let nextSunday = calendar.date(from: components) else { return nil }
            if nextSunday <= baseDate {
                components.weekOfYear = components.weekOfYear! + 1
                return calendar.date(from: components)
            }
            return nextSunday
        } else if levelLower.contains("month") {
            // Monthly resets at next month-end after the base date
            var components = calendar.dateComponents([.year, .month], from: baseDate)
            components.month = components.month! + 1
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
            guard let nextMonthStart = calendar.date(from: components) else { return nil }
            let lastDayOfMonth = nextMonthStart.addingTimeInterval(-1)
            if lastDayOfMonth <= baseDate {
                components.month = components.month! + 1
                guard let nextNextMonthStart = calendar.date(from: components) else { return nil }
                return nextNextMonthStart.addingTimeInterval(-1)
            }
            return lastDayOfMonth
        }
        return nil
    }

    /// Window duration in minutes based on limit type
    private static func windowMinutes(for level: String) -> Int? {
        let levelLower = level.lowercased()
        if levelLower.contains("session") {
            return 5 * 60  // 5 hours
        } else if levelLower.contains("week") {
            return 7 * 24 * 60  // 7 days
        } else if levelLower.contains("month") {
            return 30 * 24 * 60  // 30 days (approximate)
        }
        return nil
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
    let Result: ArkQuotaResult?
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

    /// Executes a curl command and parses the response
    public static func fetchViaCurl(curlCommand: String) async throws -> ArkUsageSnapshot? {
        // Execute curl command
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", curlCommand]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard !data.isEmpty else {
            Self.log.error("Curl returned empty response")
            return nil
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("Curl response: \(jsonString)")
        }

        // Parse the JSON response
        return try Self.parseUsageSnapshot(from: data)
    }

    /// Fetches usage stats from ARK using the provided API key and/or cookie
    public static func fetchUsage(
        apiKey: String,
        cookieHeader: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> ArkUsageSnapshot
    {
        guard !apiKey.isEmpty || (cookieHeader != nil && !cookieHeader!.isEmpty) else {
            throw ArkUsageError.invalidCredentials
        }

        let quotaURL = self.resolveQuotaURL(environment: environment)

        var request = URLRequest(url: quotaURL)
        request.httpMethod = "POST"

        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-ca-key")
        }

        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add cookie header if provided
        if let cookie = cookieHeader, !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

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

        guard let result = apiResponse.Result else {
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

    /// Parses a curl command string and extracts the cookie header
    public static func parseCurlCommand(_ curlCommand: String) -> String? {
        // Extract -b or --cookie values
        let patterns = [
            #"-b\s+['"]([^'"]+)['"]"#,
            #"--cookie\s+['"]([^'"]+)['"]"#,
            #"-b\s+(\S+)"#,
            #"--cookie\s+(\S+)"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: curlCommand, options: [], range: NSRange(curlCommand.startIndex..., in: curlCommand)),
               let range = Range(match.range(at: 1), in: curlCommand)
            {
                return String(curlCommand[range])
            }
        }

        return nil
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

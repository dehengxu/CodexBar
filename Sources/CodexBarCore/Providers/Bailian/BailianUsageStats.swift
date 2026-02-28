import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Bailian usage limit types from the API
public enum BailianLimitType: String, Sendable {
    case session = "per5Hour"
    case weekly = "perWeek"
    case monthly = "perBillMonth"
}

/// Bailian usage response structure
public struct BailianUsageSnapshot: Sendable {
    public let sessionLimit: BailianLimitEntry?
    public let weeklyLimit: BailianLimitEntry?
    public let monthlyLimit: BailianLimitEntry?
    public let planName: String?
    public let updatedAt: Date

    public init(
        sessionLimit: BailianLimitEntry?,
        weeklyLimit: BailianLimitEntry?,
        monthlyLimit: BailianLimitEntry?,
        planName: String?,
        updatedAt: Date)
    {
        self.sessionLimit = sessionLimit
        self.weeklyLimit = weeklyLimit
        self.monthlyLimit = monthlyLimit
        self.planName = planName
        self.updatedAt = updatedAt
    }

    /// Returns true if this snapshot contains valid Bailian data
    public var isValid: Bool {
        self.sessionLimit != nil || self.weeklyLimit != nil || self.monthlyLimit != nil
    }
}

extension BailianUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primary = self.sessionLimit.map { Self.rateWindow(for: $0) }
        let secondary = self.weeklyLimit.map { Self.rateWindow(for: $0) }
        let tertiary = self.monthlyLimit.map { Self.rateWindow(for: $0) }

        let planName = self.planName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginMethod = (planName?.isEmpty ?? true) ? nil : planName
        let identity = ProviderIdentitySnapshot(
            providerID: .bailian,
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

    private static func rateWindow(for limit: BailianLimitEntry) -> RateWindow {
        RateWindow(
            usedPercent: limit.usedPercent,
            windowMinutes: limit.windowMinutes,
            resetsAt: limit.nextResetTime,
            resetDescription: limit.limitType.rawValue)
    }
}

/// A single limit entry from the Bailian API
public struct BailianLimitEntry: Sendable {
    public let limitType: BailianLimitType
    public let usedCount: Int
    public let totalCount: Int
    public let nextResetTime: Date?

    public init(limitType: BailianLimitType, usedCount: Int, totalCount: Int, nextResetTime: Date?) {
        self.limitType = limitType
        self.usedCount = usedCount
        self.totalCount = totalCount
        self.nextResetTime = nextResetTime
    }

    public var usedPercent: Double {
        guard self.totalCount > 0 else { return 0 }
        return (Double(self.usedCount) / Double(self.totalCount)) * 100
    }

    public var windowMinutes: Int? {
        switch self.limitType {
        case .session:
            return 5 * 60  // 5 hours
        case .weekly:
            return 7 * 24 * 60  // 7 days
        case .monthly:
            return 30 * 24 * 60  // 30 days
        }
    }
}

/// Bailian quota API response
private struct BailianQuotaResponse: Decodable {
    let data: BailianQuotaData?
}

private struct BailianQuotaData: Decodable {
    let DataV2: BailianQuotaDataV2?
}

private struct BailianQuotaDataV2: Decodable {
    let data: BailianQuotaInnerData?
}

private struct BailianQuotaInnerData: Decodable {
    let codingPlanInstanceInfos: [BailianCodingPlanInstance]?
}

private struct BailianCodingPlanInstance: Decodable {
    let codingPlanQuotaInfo: BailianQuotaInfo?
}

private struct BailianQuotaInfo: Decodable {
    let per5HourUsedQuota: Int?
    let per5HourTotalQuota: Int?
    let per5HourQuotaNextRefreshTime: Int64?
    let perWeekUsedQuota: Int?
    let perWeekTotalQuota: Int?
    let perWeekQuotaNextRefreshTime: Int64?
    let perBillMonthUsedQuota: Int?
    let perBillMonthTotalQuota: Int?
    let perBillMonthQuotaNextRefreshTime: Int64?

    func toLimitEntry(type: BailianLimitType) -> BailianLimitEntry? {
        let used: Int
        let total: Int
        let resetTime: Int64?

        switch type {
        case .session:
            guard let u = per5HourUsedQuota, let t = per5HourTotalQuota else { return nil }
            used = u
            total = t
            resetTime = per5HourQuotaNextRefreshTime
        case .weekly:
            guard let u = perWeekUsedQuota, let t = perWeekTotalQuota else { return nil }
            used = u
            total = t
            resetTime = perWeekQuotaNextRefreshTime
        case .monthly:
            guard let u = perBillMonthUsedQuota, let t = perBillMonthTotalQuota else { return nil }
            used = u
            total = t
            resetTime = perBillMonthQuotaNextRefreshTime
        }

        let resetDate = resetTime.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        return BailianLimitEntry(
            limitType: type,
            usedCount: used,
            totalCount: total,
            nextResetTime: resetDate)
    }
}

/// Fetches usage stats from the Bailian API
public struct BailianUsageFetcher: Sendable {
    private static let log = CodexBarLog.logger(LogCategories.bailianUsage)

    /// Default Bailian host
    private static let defaultHost = "bailian-cs.console.aliyun.com"

    /// Path for Bailian quota API
    private static let quotaAPIPath = "data/api.json?action=BroadScopeAspnGateway&product=sfm_bailian&api=zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2&_v=undefined"

    /// Resolves the quota URL using (in order):
    /// 1) `BAILIAN_QUOTA_URL` environment override (full URL).
    /// 2) `BAILIAN_API_HOST` environment override (host/base URL).
    /// 3) Default Bailian host.
    public static func resolveQuotaURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL
    {
        if let override = BailianSettingsReader.quotaURL(environment: environment) {
            return override
        }
        let host = BailianSettingsReader.apiHost(environment: environment) ?? Self.defaultHost
        return URL(string: "https://\(host)/\(Self.quotaAPIPath)")!
    }

    /// Fetches usage stats from Bailian using the provided API key
    public static func fetchUsage(
        apiKey: String,
        environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> BailianUsageSnapshot
    {
        guard !apiKey.isEmpty else {
            throw BailianUsageError.invalidCredentials
        }

        let quotaURL = self.resolveQuotaURL(environment: environment)

        var request = URLRequest(url: quotaURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-ca-key")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BailianUsageError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("Bailian API returned \(httpResponse.statusCode): \(errorMessage)")
            throw BailianUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        guard !data.isEmpty else {
            Self.log.error("Bailian API returned empty body (HTTP 200)")
            throw BailianUsageError.parseFailed("Empty response body")
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("Bailian API response: \(jsonString)")
        }

        do {
            return try Self.parseUsageSnapshot(from: data)
        } catch let error as DecodingError {
            Self.log.error("Bailian JSON decoding error: \(error.localizedDescription)")
            throw BailianUsageError.parseFailed(error.localizedDescription)
        } catch let error as BailianUsageError {
            throw error
        } catch {
            Self.log.error("Bailian parsing error: \(error.localizedDescription)")
            throw BailianUsageError.parseFailed(error.localizedDescription)
        }
    }

    static func parseUsageSnapshot(from data: Data) throws -> BailianUsageSnapshot {
        guard !data.isEmpty else {
            throw BailianUsageError.parseFailed("Empty response body")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(BailianQuotaResponse.self, from: data)

        guard let quotaData = apiResponse.data?.DataV2?.data else {
            throw BailianUsageError.parseFailed("Missing data")
        }

        var sessionLimit: BailianLimitEntry?
        var weeklyLimit: BailianLimitEntry?
        var monthlyLimit: BailianLimitEntry?

        if let instances = quotaData.codingPlanInstanceInfos {
            for instance in instances {
                if let quotaInfo = instance.codingPlanQuotaInfo {
                    sessionLimit = quotaInfo.toLimitEntry(type: .session)
                    weeklyLimit = quotaInfo.toLimitEntry(type: .weekly)
                    monthlyLimit = quotaInfo.toLimitEntry(type: .monthly)
                    break  // Use first instance
                }
            }
        }

        return BailianUsageSnapshot(
            sessionLimit: sessionLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            planName: nil,
            updatedAt: Date())
    }
}

/// Errors that can occur during Bailian usage fetching
public enum BailianUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Bailian API credentials"
        case let .networkError(message):
            return "Bailian network error: \(message)"
        case let .apiError(message):
            return "Bailian API error: \(message)"
        case let .parseFailed(message):
            return "Failed to parse Bailian response: \(message)"
        }
    }
}

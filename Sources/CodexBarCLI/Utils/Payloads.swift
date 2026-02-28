import CodexBarCore
import Foundation

// MARK: - Result Types

public struct ProviderResult {
    public let provider: UsageProvider
    public let success: Bool
    public let usage: UsageSnapshot?
    public let credits: CreditsSnapshot?
    public let error: Error?

    public init(
        provider: UsageProvider,
        success: Bool,
        usage: UsageSnapshot? = nil,
        credits: CreditsSnapshot? = nil,
        error: Error? = nil
    ) {
        self.provider = provider
        self.success = success
        self.usage = usage
        self.credits = credits
        self.error = error
    }
}

public struct CostResult {
    public let provider: UsageProvider
    public let success: Bool
    public let snapshot: CostUsageTokenSnapshot?
    public let error: Error?

    public init(
        provider: UsageProvider,
        success: Bool,
        snapshot: CostUsageTokenSnapshot? = nil,
        error: Error? = nil
    ) {
        self.provider = provider
        self.success = success
        self.snapshot = snapshot
        self.error = error
    }
}

// MARK: - JSON Payloads

public struct ProviderPayload: Codable {
    public let provider: String
    public let usedPercent: Double?
    public let resetsAt: Date?
    public let accountEmail: String?
    public let updatedAt: Date
    public let error: String?

    public init(
        provider: String,
        usedPercent: Double? = nil,
        resetsAt: Date? = nil,
        accountEmail: String? = nil,
        updatedAt: Date = Date(),
        error: String? = nil
    ) {
        self.provider = provider
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.accountEmail = accountEmail
        self.updatedAt = updatedAt
        self.error = error
    }
}

public struct CostPayload: Codable {
    public let provider: String
    public let sessionCostUSD: Double?
    public let last30DaysCostUSD: Double?
    public let error: String?

    public init(
        provider: String,
        sessionCostUSD: Double? = nil,
        last30DaysCostUSD: Double? = nil,
        error: String? = nil
    ) {
        self.provider = provider
        self.sessionCostUSD = sessionCostUSD
        self.last30DaysCostUSD = last30DaysCostUSD
        self.error = error
    }
}

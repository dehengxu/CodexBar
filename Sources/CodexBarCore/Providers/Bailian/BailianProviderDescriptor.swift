import Foundation

public enum BailianProviderDescriptor {
    static let descriptor = BailianProviderDescriptor.makeDescriptor()
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .bailian,
            metadata: ProviderMetadata(
                id: .bailian,
                displayName: "Bailian",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Bailian usage",
                cliName: "bailian",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://bailian.console.aliyun.com/",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .bailian,
                iconResourceName: "ProviderIcon-bailian",
                color: ProviderColor(red: 255 / 255, green: 102 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Bailian cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [BailianAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "bailian",
                versionDetector: nil))
    }
}

struct BailianAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "bailian.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw BailianSettingsError.missingToken
        }
        let usage = try await BailianUsageFetcher.fetchUsage(
            apiKey: apiKey,
            environment: context.env)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.bailianToken(environment: environment)
    }
}

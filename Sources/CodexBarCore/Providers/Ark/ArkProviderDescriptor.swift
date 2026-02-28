import Foundation

public enum ArkProviderDescriptor {
    static let descriptor = ArkProviderDescriptor.makeDescriptor()
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .ark,
            metadata: ProviderMetadata(
                id: .ark,
                displayName: "ARK",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show ARK usage",
                cliName: "ark",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.volcengine.com/ark",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .ark,
                iconResourceName: "ProviderIcon-ark",
                color: ProviderColor(red: 64 / 255, green: 158 / 255, blue: 255 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "ARK cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [ArkAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "ark",
                versionDetector: nil))
    }
}

struct ArkAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "ark.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw ArkSettingsError.missingToken
        }
        let usage = try await ArkUsageFetcher.fetchUsage(
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
        ProviderTokenResolver.arkToken(environment: environment)
    }
}

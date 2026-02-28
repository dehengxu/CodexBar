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
        // Check for API token or curl command
        if Self.resolveToken(environment: context.env) != nil {
            return true
        }
        // Check for curl command with cookies
        if let curlCommand = context.settings?.ark?.curlCommand,
           !curlCommand.isEmpty,
           ArkUsageFetcher.parseCurlCommand(curlCommand) != nil {
            return true
        }
        return false
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        var apiKey: String?
        var cookieHeader: String?

        // Try to get API key from environment
        apiKey = Self.resolveToken(environment: context.env)

        // Try to get cookie from curl command
        if let curlCommand = context.settings?.ark?.curlCommand,
           !curlCommand.isEmpty {
            cookieHeader = ArkUsageFetcher.parseCurlCommand(curlCommand)
        }

        // Also check direct cookie header setting
        if cookieHeader == nil || cookieHeader?.isEmpty == true {
            cookieHeader = context.settings?.ark?.cookieHeader
        }

        // Use API key if available, otherwise use cookie-only mode
        let usage: ArkUsageSnapshot

        if let key = apiKey, !key.isEmpty {
            // Use API key + cookie
            usage = try await ArkUsageFetcher.fetchUsage(
                apiKey: key,
                cookieHeader: cookieHeader,
                environment: context.env)
        } else if let cookie = cookieHeader, !cookie.isEmpty {
            // Use cookie only (from curl command or manual)
            usage = try await ArkUsageFetcher.fetchUsage(
                apiKey: "",
                cookieHeader: cookie,
                environment: context.env)
        } else {
            throw ArkSettingsError.missingToken
        }

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

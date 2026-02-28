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
        // Check for API token or curl command
        if Self.resolveToken(environment: context.env) != nil {
            return true
        }
        // Check for curl command with cookies
        if let curlCommand = context.settings?.bailian?.curlCommand,
           !curlCommand.isEmpty,
           BailianUsageFetcher.parseCurlCommand(curlCommand) != nil {
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
        if let curlCommand = context.settings?.bailian?.curlCommand,
           !curlCommand.isEmpty {
            cookieHeader = BailianUsageFetcher.parseCurlCommand(curlCommand)
        }

        // Also check direct cookie header setting
        if cookieHeader == nil || cookieHeader?.isEmpty == true {
            cookieHeader = context.settings?.bailian?.cookieHeader
        }

        // Use API key if available, otherwise use cookie-only mode
        let usage: BailianUsageSnapshot

        if let key = apiKey, !key.isEmpty {
            // Use API key + cookie
            usage = try await BailianUsageFetcher.fetchUsage(
                apiKey: key,
                cookieHeader: cookieHeader,
                environment: context.env)
        } else if let cookie = cookieHeader, !cookie.isEmpty {
            // Use cookie only (from curl command or manual)
            usage = try await BailianUsageFetcher.fetchUsage(
                apiKey: "",
                cookieHeader: cookie,
                environment: context.env)
        } else {
            throw BailianSettingsError.missingToken
        }

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

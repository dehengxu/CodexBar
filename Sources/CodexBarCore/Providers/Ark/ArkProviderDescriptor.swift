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
                monthlyLabel: "Monthly",
                opusLabel: nil,
                supportsOpus: false,
                supportsTertiary: true,
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
        // Check for API token in environment
        if Self.resolveToken(environment: context.env) != nil {
            return true
        }
        // Check for curl command
        if let curlCommand = context.settings?.ark?.curlCommand,
           !curlCommand.isEmpty {
            return true
        }
        // Check for cookie header
        if let cookieHeader = context.settings?.ark?.cookieHeader,
           !cookieHeader.isEmpty {
            return true
        }
        return false
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        // Priority: 1. curl command 2. cookie header 3. API key
        var usage: ArkUsageSnapshot?

        // Try curl command first
        if let curlCommand = context.settings?.ark?.curlCommand,
           !curlCommand.isEmpty {
            do {
                usage = try await ArkUsageFetcher.fetchViaCurl(curlCommand: curlCommand)
                if usage != nil {
                    return self.makeResult(
                        usage: usage!.toUsageSnapshot(),
                        sourceLabel: "curl")
                }
            } catch {
                // Continue to try other methods
            }
        }

        // Try cookie header
        if let cookieHeader = context.settings?.ark?.cookieHeader,
           !cookieHeader.isEmpty {
            let apiKey = Self.resolveToken(environment: context.env) ?? ""
            usage = try await ArkUsageFetcher.fetchUsage(
                apiKey: apiKey,
                cookieHeader: cookieHeader,
                environment: context.env)
            return self.makeResult(
                usage: usage!.toUsageSnapshot(),
                sourceLabel: "api")
        }

        // Try API key
        if let apiKey = Self.resolveToken(environment: context.env), !apiKey.isEmpty {
            usage = try await ArkUsageFetcher.fetchUsage(
                apiKey: apiKey,
                environment: context.env)
            return self.makeResult(
                usage: usage!.toUsageSnapshot(),
                sourceLabel: "api")
        }

        throw ArkSettingsError.missingToken
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.arkToken(environment: environment)
    }
}

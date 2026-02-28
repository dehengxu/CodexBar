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
        // Check for API token in environment
        if Self.resolveToken(environment: context.env) != nil {
            return true
        }
        // Check for curl command
        if let curlCommand = context.settings?.bailian?.curlCommand,
           !curlCommand.isEmpty {
            return true
        }
        // Check for cookie header
        if let cookieHeader = context.settings?.bailian?.cookieHeader,
           !cookieHeader.isEmpty {
            return true
        }
        return false
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        // Priority: 1. curl command 2. cookie header 3. API key
        var usage: BailianUsageSnapshot?

        // Try curl command first
        if let curlCommand = context.settings?.bailian?.curlCommand,
           !curlCommand.isEmpty {
            do {
                usage = try await BailianUsageFetcher.fetchViaCurl(curlCommand: curlCommand)
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
        if let cookieHeader = context.settings?.bailian?.cookieHeader,
           !cookieHeader.isEmpty {
            let apiKey = Self.resolveToken(environment: context.env) ?? ""
            usage = try await BailianUsageFetcher.fetchUsage(
                apiKey: apiKey,
                cookieHeader: cookieHeader,
                environment: context.env)
            return self.makeResult(
                usage: usage!.toUsageSnapshot(),
                sourceLabel: "api")
        }

        // Try API key
        if let apiKey = Self.resolveToken(environment: context.env), !apiKey.isEmpty {
            usage = try await BailianUsageFetcher.fetchUsage(
                apiKey: apiKey,
                environment: context.env)
            return self.makeResult(
                usage: usage!.toUsageSnapshot(),
                sourceLabel: "api")
        }

        throw BailianSettingsError.missingToken
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.bailianToken(environment: environment)
    }
}

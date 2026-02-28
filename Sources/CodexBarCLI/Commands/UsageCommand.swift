import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Synchronous Entry

public func runUsageSync(_ argv: [String]) {
    let globalOpts = parseGlobalOptions(argv)
    let (opts, _) = parseUsageOptions(argv)

    // Setup logging
    let level = resolvedLogLevel(verbose: opts.verbose || globalOpts.verbose, rawLevel: opts.logLevel ?? globalOpts.logLevel)
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: level, json: opts.jsonOutput || globalOpts.jsonOutput))

    // Determine output format
    let format = globalOpts.format == .json ? .json : opts.format
    let pretty = opts.pretty || globalOpts.pretty
    let jsonOnly = opts.jsonOnly || globalOpts.jsonOnly
    let continueOnError = globalOpts.continueOnError

    // Load config to check enabled providers
    let configStore = CodexBarConfigStore()
    let config: CodexBarConfig
    do {
        config = try configStore.loadOrCreateDefault()
    } catch {
        if !jsonOnly {
            fputs("Error loading config: \(error.localizedDescription)\n", stderr)
        }
        exit(CLIExitCode.configError.rawValue)
    }

    // Get providers to query
    let providers: [UsageProvider]
    let providerWasSpecified = argv.contains { $0 == "--provider" || $0 == "-p" }

    if providerWasSpecified {
        // User specified --provider, use it but check if enabled
        let specifiedProviders = opts.provider.asList
        let enabledProviders = Set(config.enabledProviders())

        // Check if any specified provider is disabled
        let disabledSpecified = specifiedProviders.filter { !enabledProviders.contains($0) }
        if !disabledSpecified.isEmpty, !jsonOnly {
            let names = disabledSpecified.map { $0.rawValue }.joined(separator: ", ")
            fputs("Warning: Provider(s) disabled in config: \(names)\n", stderr)
        }

        providers = specifiedProviders
    } else {
        // No --provider, use config's enabled providers
        let enabledFromConfig = config.enabledProviders()
        if enabledFromConfig.isEmpty {
            // Fallback to default if no providers enabled
            providers = opts.provider.asList
        } else {
            providers = enabledFromConfig
        }
    }

    // Use a simple async wrapper
    let semaphore = DispatchSemaphore(value: 0)
    let exitCodeBox = ExitCodeBox()

    Task {
        let code = await runUsageForProviders(
            providers: providers,
            format: format,
            pretty: pretty,
            jsonOnly: jsonOnly,
            continueOnError: continueOnError,
            sourceMode: opts.source,
            webTimeout: opts.webTimeout
        )
        exitCodeBox.value = code
        semaphore.signal()
    }

    semaphore.wait()
    exit(exitCodeBox.value)
}

// MARK: - Async Implementation

public func runUsageForProviders(
    providers: [UsageProvider],
    format: OutputFormat,
    pretty: Bool,
    jsonOnly: Bool,
    continueOnError: Bool,
    sourceMode: ProviderSourceMode?,
    webTimeout: Double?
) async -> Int32 {
    let browserDetection = BrowserDetection()
    let fetcher = UsageFetcher()
    let claudeFetcher = ClaudeUsageFetcher(browserDetection: browserDetection)

    var results: [ProviderResult] = []
    var hasError = false

    for provider in providers {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)

        // Create fetch context
        let context = ProviderFetchContext(
            runtime: .cli,
            sourceMode: sourceMode ?? .auto,
            includeCredits: true,
            webTimeout: webTimeout ?? 60,
            webDebugDumpHTML: false,
            verbose: false,
            env: ProcessInfo.processInfo.environment,
            settings: nil,
            fetcher: fetcher,
            claudeFetcher: claudeFetcher,
            browserDetection: browserDetection
        )

        do {
            let result = try await descriptor.fetch(context: context)
            results.append(ProviderResult(
                provider: provider,
                success: true,
                usage: result.usage,
                credits: result.credits,
                error: nil
            ))
        } catch {
            hasError = true
            results.append(ProviderResult(
                provider: provider,
                success: false,
                usage: nil,
                credits: nil,
                error: error
            ))

            if !continueOnError {
                break
            }
        }
    }

    // Output results
    switch format {
    case .text:
        outputUsageText(results: results, jsonOnly: jsonOnly)
    case .json:
        outputUsageJSON(results: results, pretty: pretty, jsonOnly: jsonOnly)
    }

    return hasError ? CLIExitCode.generalError.rawValue : CLIExitCode.success.rawValue
}

// MARK: - Helpers

private func resolvedLogLevel(verbose: Bool, rawLevel: String?) -> CodexBarLog.Level {
    CodexBarLog.parseLevel(rawLevel) ?? (verbose ? .debug : .error)
}

import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Synchronous Entry

public func runCostSync(_ argv: [String]) {
    let globalOpts = parseGlobalOptions(argv)
    let (opts, _) = parseCostOptions(argv)

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

    // Get providers to query - compute first into temp var, then assign to let
    let providers: [UsageProvider]
    let providerWasSpecified = argv.contains { $0 == "--provider" || $0 == "-p" }

    if providerWasSpecified {
        // User specified --provider, use it but check if enabled
        let specifiedProviders = opts.provider.asList.filter { provider in
            // Only Claude and Codex support cost usage currently
            provider == .claude || provider == .codex
        }
        let enabledProviders = Set(config.enabledProviders())

        // Check if any specified provider is disabled
        let disabledSpecified = specifiedProviders.filter { !enabledProviders.contains($0) }
        if !disabledSpecified.isEmpty, !jsonOnly {
            let names = disabledSpecified.map { $0.rawValue }.joined(separator: ", ")
            fputs("Warning: Provider(s) disabled in config: \(names)\n", stderr)
        }

        providers = specifiedProviders
    } else {
        // No --provider, use config's enabled providers (filtered to cost-supporting ones)
        let enabledFromConfig = config.enabledProviders().filter { provider in
            provider == .claude || provider == .codex
        }
        if enabledFromConfig.isEmpty {
            // Fallback to default if no providers enabled
            providers = opts.provider.asList.filter { provider in
                provider == .claude || provider == .codex
            }
        } else {
            providers = enabledFromConfig
        }
    }

    if providers.isEmpty {
        if !jsonOnly {
            fputs("Error: No providers support cost usage (only claude and codex)\n", stderr)
        }
        exit(CLIExitCode.providerNotFound.rawValue)
    }

    let semaphore = DispatchSemaphore(value: 0)
    let exitCodeBox = ExitCodeBox()

    Task {
        let code = await runCostForProviders(
            providers: providers,
            format: format,
            pretty: pretty,
            jsonOnly: jsonOnly,
            continueOnError: continueOnError,
            refresh: opts.refresh
        )
        exitCodeBox.value = code
        semaphore.signal()
    }

    semaphore.wait()
    exit(exitCodeBox.value)
}

// MARK: - Async Implementation

public func runCostForProviders(
    providers: [UsageProvider],
    format: OutputFormat,
    pretty: Bool,
    jsonOnly: Bool,
    continueOnError: Bool,
    refresh: Bool
) async -> Int32 {
    let fetcher = CostUsageFetcher()
    var results: [CostResult] = []
    var hasError = false

    for provider in providers {
        do {
            let snapshot = try await fetcher.loadTokenSnapshot(provider: provider, forceRefresh: refresh)
            results.append(CostResult(
                provider: provider,
                success: true,
                snapshot: snapshot,
                error: nil
            ))
        } catch {
            hasError = true
            results.append(CostResult(
                provider: provider,
                success: false,
                snapshot: nil,
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
        outputCostText(results: results, jsonOnly: jsonOnly)
    case .json:
        outputCostJSON(results: results, pretty: pretty, jsonOnly: jsonOnly)
    }

    return hasError ? CLIExitCode.generalError.rawValue : CLIExitCode.success.rawValue
}

// MARK: - Helpers

private func resolvedLogLevel(verbose: Bool, rawLevel: String?) -> CodexBarLog.Level {
    CodexBarLog.parseLevel(rawLevel) ?? (verbose ? .debug : .error)
}

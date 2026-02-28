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

    // Get providers to query (only those supporting cost)
    let providers = opts.provider.asList.filter { provider in
        // Only Claude and Codex support cost usage currently
        provider == .claude || provider == .codex
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

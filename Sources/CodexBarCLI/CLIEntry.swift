import CodexBarCore

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Exit Codes

enum CLIExitCode: Int32 {
    case success = 0
    case generalError = 1
    case providerNotFound = 2
    case parseError = 3
    case timeout = 4
    case configError = 5
}

// Thread-safe box for exit code
final class ExitCodeBox: @unchecked Sendable {
    var value: Int32 = CLIExitCode.success.rawValue
}

// MARK: - CLI Entry Point

@main
struct CodexBarCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let argv = effectiveArgv(args)

        // Handle global help/version first
        if argv.contains("-h") || argv.contains("--help") {
            if argv.count > 1 {
                printHelp(for: argv.count > 1 ? argv[1] : nil)
            } else {
                printHelp(for: nil)
            }
            return
        }
        if argv.contains("-V") || argv.contains("--version") {
            printVersion()
            return
        }

        // Route to command
        let command = argv.first ?? "usage"
        switch command {
        case "usage":
            runUsageSync(argv)
        case "cost":
            runCostSync(argv)
        case "config":
            runConfig(argv)
        default:
            // Default to usage if no command or looks like options
            if command.hasPrefix("-") {
                runUsageSync(argv)
            } else {
                fputs("Unknown command: \(command)\n", stderr)
                fputs("Run 'codexbar --help' for usage information.\n", stderr)
                exit(CLIExitCode.generalError.rawValue)
            }
        }
    }

    // MARK: - Helpers

    static func effectiveArgv(_ argv: [String]) -> [String] {
        guard let first = argv.first else { return ["usage"] }
        if first.hasPrefix("-") { return ["usage"] + argv }
        return argv
    }

    static func resolvedLogLevel(verbose: Bool, rawLevel: String?) -> CodexBarLog.Level {
        CodexBarLog.parseLevel(rawLevel) ?? (verbose ? .debug : .error)
    }
}

// MARK: - Global Options

struct GlobalOptions {
    var verbose: Bool = false
    var jsonOutput: Bool = false
    var logLevel: String?
    var format: OutputFormat = .text
    var jsonOnly: Bool = false
    var pretty: Bool = false
    var continueOnError: Bool = false
}

func parseGlobalOptions(_ argv: [String]) -> GlobalOptions {
    var opts = GlobalOptions()
    var i = 0
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "-v", "--verbose":
            opts.verbose = true
            i += 1
        case "--json-output":
            opts.jsonOutput = true
            i += 1
        case "--log-level":
            if i + 1 < argv.count {
                opts.logLevel = argv[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "-f", "--format":
            if i + 1 < argv.count {
                opts.format = OutputFormat(rawValue: argv[i + 1]) ?? .text
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            opts.format = .json
            i += 1
        case "--json-only":
            opts.jsonOnly = true
            i += 1
        case "--pretty":
            opts.pretty = true
            i += 1
        case "--continue-on-error":
            opts.continueOnError = true
            i += 1
        default:
            i += 1
        }
    }
    return opts
}

// MARK: - Output Format

enum OutputFormat: String, Sendable {
    case text
    case json
}

// MARK: - Provider Selection

enum ProviderSelection: Sendable {
    case single(UsageProvider)
    case both
    case all

    var asList: [UsageProvider] {
        switch self {
        case let .single(provider):
            return [provider]
        case .both:
            let primary = ProviderDescriptorRegistry.all.filter { $0.metadata.isPrimaryProvider }
            if !primary.isEmpty {
                return primary.map { $0.id }
            }
            return Array(ProviderDescriptorRegistry.all.prefix(2).map { $0.id })
        case .all:
            return ProviderDescriptorRegistry.all.map { $0.id }
        }
    }
}

// MARK: - Usage Options

struct UsageOptions {
    var verbose: Bool = false
    var jsonOutput: Bool = false
    var logLevel: String?
    var provider: ProviderSelection = .both
    var account: String?
    var accountIndex: Int?
    var allAccounts: Bool = false
    var format: OutputFormat = .text
    var jsonOnly: Bool = false
    var noCredits: Bool = false
    var noColor: Bool = false
    var pretty: Bool = false
    var status: Bool = false
    var source: ProviderSourceMode?
    var webTimeout: Double?
}

func parseUsageOptions(_ argv: [String]) -> (options: UsageOptions, remaining: [String]) {
    var opts = UsageOptions()
    var i = 0
    var remaining: [String] = []

    // Skip command name
    if argv.first == "usage" {
        i = 1
    }

    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "-v", "--verbose":
            opts.verbose = true
            i += 1
        case "--json-output":
            opts.jsonOutput = true
            i += 1
        case "--log-level":
            if i + 1 < argv.count {
                opts.logLevel = argv[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "--provider", "-p":
            if i + 1 < argv.count {
                let value = argv[i + 1].lowercased()
                if value == "both" {
                    opts.provider = .both
                } else if value == "all" {
                    opts.provider = .all
                } else if let provider = ProviderDescriptorRegistry.cliNameMap[value] {
                    opts.provider = .single(provider)
                }
                i += 2
            } else {
                i += 1
            }
        case "--account":
            if i + 1 < argv.count {
                opts.account = argv[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "--account-index":
            if i + 1 < argv.count {
                opts.accountIndex = Int(argv[i + 1])
                i += 2
            } else {
                i += 1
            }
        case "--all-accounts":
            opts.allAccounts = true
            i += 1
        case "-f", "--format":
            if i + 1 < argv.count {
                opts.format = OutputFormat(rawValue: argv[i + 1]) ?? .text
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            opts.format = .json
            i += 1
        case "--json-only":
            opts.jsonOnly = true
            i += 1
        case "--no-credits":
            opts.noCredits = true
            i += 1
        case "--no-color":
            opts.noColor = true
            i += 1
        case "--pretty":
            opts.pretty = true
            i += 1
        case "--status":
            opts.status = true
            i += 1
        case "--web":
            opts.source = .web
            i += 1
        case "--source":
            if i + 1 < argv.count {
                opts.source = ProviderSourceMode(rawValue: argv[i + 1])
                i += 2
            } else {
                i += 1
            }
        case "--web-timeout":
            if i + 1 < argv.count {
                opts.webTimeout = Double(argv[i + 1])
                i += 2
            } else {
                i += 1
            }
        case "--web-debug-dump-html":
            i += 1
        case "--antigravity-plan-debug":
            i += 1
        case "--augment-debug":
            i += 1
        default:
            remaining.append(arg)
            i += 1
        }
    }

    return (opts, remaining)
}

// MARK: - Cost Options

struct CostOptions {
    var verbose: Bool = false
    var jsonOutput: Bool = false
    var logLevel: String?
    var provider: ProviderSelection = .both
    var format: OutputFormat = .text
    var jsonOnly: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var refresh: Bool = false
}

func parseCostOptions(_ argv: [String]) -> (options: CostOptions, remaining: [String]) {
    var opts = CostOptions()
    var i = 0
    var remaining: [String] = []

    // Skip command name
    if argv.first == "cost" {
        i = 1
    }

    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "-v", "--verbose":
            opts.verbose = true
            i += 1
        case "--json-output":
            opts.jsonOutput = true
            i += 1
        case "--log-level":
            if i + 1 < argv.count {
                opts.logLevel = argv[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "--provider", "-p":
            if i + 1 < argv.count {
                let value = argv[i + 1].lowercased()
                if value == "both" {
                    opts.provider = .both
                } else if value == "all" {
                    opts.provider = .all
                } else if let provider = ProviderDescriptorRegistry.cliNameMap[value] {
                    opts.provider = .single(provider)
                }
                i += 2
            } else {
                i += 1
            }
        case "-f", "--format":
            if i + 1 < argv.count {
                opts.format = OutputFormat(rawValue: argv[i + 1]) ?? .text
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            opts.format = .json
            i += 1
        case "--json-only":
            opts.jsonOnly = true
            i += 1
        case "--pretty":
            opts.pretty = true
            i += 1
        case "--no-color":
            opts.noColor = true
            i += 1
        case "--refresh":
            opts.refresh = true
            i += 1
        default:
            remaining.append(arg)
            i += 1
        }
    }

    return (opts, remaining)
}

// MARK: - Commands (Synchronous wrappers)

func runUsageSync(_ argv: [String]) {
    let globalOpts = parseGlobalOptions(argv)
    let (opts, _) = parseUsageOptions(argv)

    // Setup logging
    let level = CodexBarCLI.resolvedLogLevel(verbose: opts.verbose || globalOpts.verbose, rawLevel: opts.logLevel ?? globalOpts.logLevel)
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: level, json: opts.jsonOutput || globalOpts.jsonOutput))

    // Determine output format
    let format = globalOpts.format == .json ? .json : opts.format
    let pretty = opts.pretty || globalOpts.pretty
    let jsonOnly = opts.jsonOnly || globalOpts.jsonOnly
    let continueOnError = globalOpts.continueOnError

    // Get providers to query
    let providers = opts.provider.asList

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

func runCostSync(_ argv: [String]) {
    let globalOpts = parseGlobalOptions(argv)
    let (opts, _) = parseCostOptions(argv)

    // Setup logging
    let level = CodexBarCLI.resolvedLogLevel(verbose: opts.verbose || globalOpts.verbose, rawLevel: opts.logLevel ?? globalOpts.logLevel)
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

// MARK: - Async Commands with Provider Filtering

func runUsageForProviders(
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

func runCostForProviders(
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

// MARK: - Result Types

struct ProviderResult {
    let provider: UsageProvider
    let success: Bool
    let usage: UsageSnapshot?
    let credits: CreditsSnapshot?
    let error: Error?
}

struct CostResult {
    let provider: UsageProvider
    let success: Bool
    let snapshot: CostUsageTokenSnapshot?
    let error: Error?
}

// MARK: - Output Formatting

func outputUsageText(results: [ProviderResult], jsonOnly: Bool) {
    var lines: [String] = []

    for result in results {
        if result.success, let usage = result.usage {
            lines.append("== \(result.provider.rawValue) ==")

            if let primary = usage.primary {
                lines.append("Primary: \(String(format: "%.1f", primary.usedPercent))% used")
                if let resetsAt = primary.resetsAt {
                    lines.append("Resets: \(resetsAt)")
                }
            }

            if let secondary = usage.secondary {
                lines.append("Secondary: \(String(format: "%.1f", secondary.usedPercent))% used")
            }

            if let identity = usage.identity, let email = identity.accountEmail {
                lines.append("Account: \(email)")
            }
        } else if let error = result.error {
            if !jsonOnly {
                lines.append("== \(result.provider.rawValue) ==")
                lines.append("Error: \(error.localizedDescription)")
            }
        }
    }

    if !lines.isEmpty {
        print(lines.joined(separator: "\n"))
    }
}

func outputUsageJSON(results: [ProviderResult], pretty: Bool, jsonOnly: Bool) {
    let payloads = results.map { result -> ProviderPayload in
        ProviderPayload(
            provider: result.provider.rawValue,
            usedPercent: result.usage?.primary?.usedPercent,
            resetsAt: result.usage?.primary?.resetsAt,
            accountEmail: result.usage?.identity?.accountEmail,
            updatedAt: result.usage?.updatedAt ?? Date(),
            error: result.success ? nil : result.error?.localizedDescription
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    if let data = try? encoder.encode(payloads), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func outputCostText(results: [CostResult], jsonOnly: Bool) {
    var lines: [String] = []

    for result in results {
        if result.success, let snapshot = result.snapshot {
            lines.append("== \(result.provider.rawValue) Cost ==")

            if let sessionCost = snapshot.sessionCostUSD {
                lines.append("Session: $\(String(format: "%.2f", sessionCost))")
            }

            if let monthlyCost = snapshot.last30DaysCostUSD {
                lines.append("Last 30 days: $\(String(format: "%.2f", monthlyCost))")
            }
        } else if let error = result.error, !jsonOnly {
            lines.append("== \(result.provider.rawValue) ==")
            lines.append("Error: \(error.localizedDescription)")
        }
    }

    if !lines.isEmpty {
        print(lines.joined(separator: "\n"))
    }
}

func outputCostJSON(results: [CostResult], pretty: Bool, jsonOnly: Bool) {
    let payloads = results.map { result -> CostPayload in
        CostPayload(
            provider: result.provider.rawValue,
            sessionCostUSD: result.snapshot?.sessionCostUSD,
            last30DaysCostUSD: result.snapshot?.last30DaysCostUSD,
            error: result.success ? nil : result.error?.localizedDescription
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    if let data = try? encoder.encode(payloads), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

// MARK: - Config Commands

func runConfig(_ argv: [String]) {
    let subcommand = argv.count > 1 ? argv[1] : "validate"

    // Setup logging
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: .error, json: false))

    switch subcommand {
    case "validate":
        runConfigValidate()
    case "dump":
        runConfigDump()
    default:
        fputs("Unknown config subcommand: \(subcommand)\n", stderr)
        fputs("Run 'codexbar --help' for usage information.\n", stderr)
        exit(CLIExitCode.generalError.rawValue)
    }
}

func runConfigValidate() {
    let config = CodexBarConfig.makeDefault()
    let issues = CodexBarConfigValidator.validate(config)

    let hasErrors = issues.contains { $0.severity == .error }

    if issues.isEmpty {
        print("Config: OK")
    } else {
        for issue in issues {
            let provider = issue.provider?.rawValue ?? "config"
            let field = issue.field ?? ""
            let prefix = "[\(issue.severity.rawValue.uppercased())]"
            let suffix = field.isEmpty ? "" : " (\(field))"
            print("\(prefix) \(provider)\(suffix): \(issue.message)")
        }
    }

    exit(hasErrors ? CLIExitCode.configError.rawValue : CLIExitCode.success.rawValue)
}

func runConfigDump() {
    let config = CodexBarConfig.makeDefault()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(config), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
    exit(CLIExitCode.success.rawValue)
}

// MARK: - Payloads

struct ProviderPayload: Codable {
    let provider: String
    let usedPercent: Double?
    let resetsAt: Date?
    let accountEmail: String?
    let updatedAt: Date
    let error: String?
}

struct CostPayload: Codable {
    let provider: String
    let sessionCostUSD: Double?
    let last30DaysCostUSD: Double?
    let error: String?
}

// MARK: - Help & Version

func printHelp(for command: String?) {
    if command == "usage" || command == "cost" || command == "config" {
        printCommandHelp(for: command!)
    } else {
        printGlobalHelp()
    }
}

func printGlobalHelp() {
    print("""
    CodexBar CLI - Multi-provider AI usage monitoring

    Usage: codexbar <command> [options]

    Commands:
      usage              Print provider usage (default)
      cost               Print local cost usage
      config             Config utilities
        validate         Validate config file
        dump            Print normalized config JSON

    Options:
      -v, --verbose     Verbose output
      --log-level       Log level (trace|verbose|debug|info|warning|error|critical)
      -f, --format      Output format (text, json) [default: text]
      -j, --json        Output as JSON
      --json-only       Emit JSON only (suppress non-JSON output)
      --pretty          Pretty-print JSON output
      -h, --help        Show this help message
      -V, --version     Show version

    Provider Options:
      --provider, -p    Provider to query (claude|codex|both|all)
      --account         Token account label to use
      --account-index   Token account index (1-based)
      --all-accounts   Fetch all token accounts

    Data Source Options (macOS only):
      --source          Data source (auto|web|cli|oauth|api)
      --web             Alias for --source web
      --web-timeout     Web fetch timeout (seconds)

    Error Handling:
      --continue-on-error  Continue querying other providers if one fails

    Exit Codes:
      0  Success
      1  General error
      2  Provider not found
      3  Parse error
      4  Timeout
      5  Config error

    Examples:
      codexbar usage
      codexbar usage --json
      codexbar usage --provider claude
      codexbar cost
      codexbar config validate
    """)
}

func printCommandHelp(for command: String) {
    switch command {
    case "usage":
        print("""
        usage - Print provider usage as text or JSON

        Usage: codexbar usage [options]

        Options:
          -v, --verbose           Enable verbose logging
          --provider, -p          Provider to query (claude|codex|both|all)
          --account              Token account label to use
          --account-index        Token account index (1-based)
          --all-accounts        Fetch all token accounts
          -f, --format           Output format (text | json)
          -j, --json             Output as JSON
          --json-only            Emit JSON only
          --no-credits           Skip credits line
          --no-color             Disable ANSI colors
          --pretty               Pretty-print JSON
          --status               Fetch and include provider status
          --source               Data source (auto|web|cli|oauth|api)
          --web                  Alias for --source web
          --web-timeout          Web fetch timeout (seconds)
          --continue-on-error    Continue on provider errors
        """)
    case "cost":
        print("""
        cost - Print local cost usage as text or JSON

        Usage: codexbar cost [options]

        Options:
          -v, --verbose         Enable verbose logging
          --provider, -p        Provider to query (claude|codex|both|all)
          -f, --format          Output format (text | json)
          -j, --json            Output as JSON
          --json-only           Emit JSON only
          --pretty              Pretty-print JSON
          --no-color            Disable ANSI colors
          --refresh             Force cache refresh
          --continue-on-error   Continue on provider errors
        """)
    case "config":
        print("""
        config - Config utilities

        Usage: codexbar config <subcommand> [options]

        Subcommands:
          validate              Validate config file
          dump                 Print normalized config JSON

        Options:
          -f, --format         Output format (text | json)
          -j, --json           Output as JSON
          --pretty             Pretty-print JSON
        """)
    default:
        printGlobalHelp()
    }
}

func printVersion() {
    print("CodexBar CLI 1.0.0")
}

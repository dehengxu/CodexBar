import CodexBarCore
import Foundation

// MARK: - Cost Options

public struct CostOptions {
    public var verbose: Bool = false
    public var jsonOutput: Bool = false
    public var logLevel: String?
    public var provider: ProviderSelection = .both
    public var format: OutputFormat = .text
    public var jsonOnly: Bool = false
    public var pretty: Bool = false
    public var noColor: Bool = false
    public var refresh: Bool = false

    public init() {}
}

public func parseCostOptions(_ argv: [String]) -> (options: CostOptions, remaining: [String]) {
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
                } else {
                    // Invalid provider - will be handled later
                    fputs("Warning: Unknown provider '\(value)'\n", stderr)
                }
                i += 2
            } else {
                fputs("Error: --provider requires a value\n", stderr)
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

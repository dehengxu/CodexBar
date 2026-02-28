import CodexBarCore
import Foundation

// MARK: - Usage Options

public struct UsageOptions {
    public var verbose: Bool = false
    public var jsonOutput: Bool = false
    public var logLevel: String?
    public var provider: ProviderSelection = .both
    public var account: String?
    public var accountIndex: Int?
    public var allAccounts: Bool = false
    public var format: OutputFormat = .text
    public var jsonOnly: Bool = false
    public var noCredits: Bool = false
    public var noColor: Bool = false
    public var pretty: Bool = false
    public var status: Bool = false
    public var source: ProviderSourceMode?
    public var webTimeout: Double?

    public init() {}
}

public func parseUsageOptions(_ argv: [String]) -> (options: UsageOptions, remaining: [String]) {
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

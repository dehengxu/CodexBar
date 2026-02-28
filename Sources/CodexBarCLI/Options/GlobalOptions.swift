import CodexBarCore
import Foundation

// MARK: - Exit Codes

public enum CLIExitCode: Int32 {
    case success = 0
    case generalError = 1
    case providerNotFound = 2
    case parseError = 3
    case timeout = 4
    case configError = 5
}

// Thread-safe box for exit code
public final class ExitCodeBox: @unchecked Sendable {
    public var value: Int32 = CLIExitCode.success.rawValue
    public init() {}
}

// MARK: - Output Format

public enum OutputFormat: String, Sendable {
    case text
    case json
}

// MARK: - Provider Selection

public enum ProviderSelection: Sendable {
    case single(UsageProvider)
    case both
    case all

    public var asList: [UsageProvider] {
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

// MARK: - Global Options

public struct GlobalOptions {
    public var verbose: Bool = false
    public var jsonOutput: Bool = false
    public var logLevel: String?
    public var format: OutputFormat = .text
    public var jsonOnly: Bool = false
    public var pretty: Bool = false
    public var continueOnError: Bool = false

    public init() {}
}

public func parseGlobalOptions(_ argv: [String]) -> GlobalOptions {
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

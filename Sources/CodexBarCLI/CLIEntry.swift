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

// MARK: - CLI Entry Point

@main
struct CodexBarCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty || args == ["usage"] {
            runUsage(args)
        } else if args.first == "cost" {
            runCost(args)
        } else if args.first == "config" {
            runConfig(args)
        } else if args.first == "--help" || args.first == "-h" {
            printHelp()
        } else {
            print("Unknown command: \(args.first ?? "")")
            print("Run 'codexbar --help' for usage information.")
            exit(1)
        }
    }
}

// MARK: - Usage Command

func runUsage(_ args: [String]) {
    var format = "text"
    var json = false
    var verbose = false
    var logLevel: String?

    // Parse options
    var i = 1
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-f", "--format":
            if i + 1 < args.count {
                format = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            json = true
            i += 1
        case "-v", "--verbose":
            verbose = true
            i += 1
        case "--log-level":
            if i + 1 < args.count {
                logLevel = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        default:
            i += 1
        }
    }

    // Setup logging
    let level = logLevel.flatMap { CodexBarLog.parseLevel($0) } ?? (verbose ? .debug : .error)
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: level, json: json))

    print("Usage: format=\(format), json=\(json)")
    // TODO: Implement actual usage fetching
}

// MARK: - Cost Command

func runCost(_ args: [String]) {
    var format = "text"
    var json = false
    var verbose = false

    var i = 2
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-f", "--format":
            if i + 1 < args.count {
                format = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            json = true
            i += 1
        case "-v", "--verbose":
            verbose = true
            i += 1
        default:
            i += 1
        }
    }

    let level = verbose ? CodexBarLog.Level.debug : CodexBarLog.Level.error
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: level, json: json))

    print("Cost: format=\(format), json=\(json)")
    // TODO: Implement actual cost fetching
}

// MARK: - Config Command

func runConfig(_ args: [String]) {
    let subcommand = args.count > 1 ? args[1] : "validate"

    switch subcommand {
    case "validate":
        print("Config validate: OK")
        // TODO: Implement config validation
    case "dump":
        print("Config dump: {}")
        // TODO: Implement config dump
    default:
        print("Unknown config subcommand: \(subcommand)")
        exit(1)
    }
}

// MARK: - Help

func printHelp() {
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
      -f, --format      Output format (text, json) [default: text]
      -j, --json        Output as JSON
      -v, --verbose     Verbose output
      --log-level       Log level (debug, info, warning, error)
      -h, --help        Show this help message

    Examples:
      codexbar usage
      codexbar usage --json
      codexbar cost -v
      codexbar config validate
    """)
}

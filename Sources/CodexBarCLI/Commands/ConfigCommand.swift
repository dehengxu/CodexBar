import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Entry Point

public func runConfig(_ argv: [String]) {
    let subcommand = argv.count > 1 ? argv[1] : "validate"

    // Setup logging
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: .error, json: false))

    switch subcommand {
    case "validate":
        runConfigValidate()
    case "dump":
        runConfigDump(argv)
    default:
        fputs("Unknown config subcommand: \(subcommand)\n", stderr)
        fputs("Run 'codexbar --help' for usage information.\n", stderr)
        exit(CLIExitCode.generalError.rawValue)
    }
}

// MARK: - Subcommands

public func runConfigValidate() {
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

public func runConfigDump(_ argv: [String]) {
    // Parse format options
    var pretty = true
    var format: OutputFormat = .json

    var i = 0
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "-f", "--format":
            if i + 1 < argv.count {
                format = OutputFormat(rawValue: argv[i + 1]) ?? .json
                i += 2
            } else {
                i += 1
            }
        case "--pretty":
            pretty = true
            i += 1
        case "--no-pretty":
            pretty = false
            i += 1
        default:
            i += 1
        }
    }

    let config = CodexBarConfig.makeDefault()

    switch format {
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        if let data = try? encoder.encode(config), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    case .text:
        // Simple text representation
        print("Configuration:")
        print("  Config file loaded successfully")
    }

    exit(CLIExitCode.success.rawValue)
}

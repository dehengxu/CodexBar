import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
}

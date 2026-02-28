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

        // Handle global help/version first
        let hasHelp = args.contains("-h") || args.contains("--help")
        let hasVersion = args.contains("-V") || args.contains("--version")

        if hasHelp {
            // Find the command name for help (skip --help/-h)
            let commandForHelp = args.first { arg in
                arg != "-h" && arg != "--help" && !arg.hasPrefix("-")
            }
            printHelp(for: commandForHelp)
            return
        }
        if hasVersion {
            printVersion()
            return
        }

        let argv = effectiveArgv(args)

        // Route to command
        let command = argv.first ?? "usage"
        switch command {
        case "usage":
            runUsageSync(argv)
        case "cost":
            runCostSync(argv)
        case "config":
            runConfig(argv)
        case "list":
            runList(argv)
        default:
            // Default to usage if no command or looks like options
            if command.hasPrefix("-") {
                runUsageSync(argv)
            } else {
                exitWithError(CLIError.unknownCommand(command), jsonOnly: false)
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

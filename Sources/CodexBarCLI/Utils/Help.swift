import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Help Output

public func printHelp(for command: String?) {
    if command == "usage" || command == "cost" || command == "config" {
        printCommandHelp(for: command!)
    } else {
        printGlobalHelp()
    }
}

public func printGlobalHelp() {
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

public func printCommandHelp(for command: String) {
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

public func printVersion() {
    print("CodexBar CLI 1.0.0")
}

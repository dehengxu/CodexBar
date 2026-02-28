import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - CLI Error Types

public enum CLIError: Error, CustomStringConvertible {
    // Provider errors
    case providerNotFound(String)
    case providerNotSupported(String, String)
    case providerFetchFailed(String, String)

    // Config errors
    case configValidationFailed([CodexBarConfigIssue])
    case configFileNotFound(String)
    case configParseError(String)

    // Parse errors
    case invalidArgument(String, String?)
    case missingRequiredArgument(String)
    case invalidProviderValue(String)
    case invalidFormatValue(String)

    // Runtime errors
    case timeout(String, TimeInterval)
    case networkError(String)
    case authenticationFailed(String)
    case noDataAvailable(String)

    // General errors
    case unknownCommand(String)
    case internalError(String)

    public var description: String {
        switch self {
        case let .providerNotFound(name):
            return "Provider not found: '\(name)'. Use 'claude', 'codex', 'both', or 'all'."
        case let .providerNotSupported(name, feature):
            return "Provider '\(name)' does not support \(feature)."
        case let .providerFetchFailed(name, reason):
            return "Failed to fetch data from '\(name)': \(reason)"

        case let .configValidationFailed(issues):
            let issueList = issues.map { "  - \($0.provider?.rawValue ?? "config"): \($0.message)" }.joined(separator: "\n")
            return "Configuration validation failed:\n\(issueList)"
        case let .configFileNotFound(path):
            return "Configuration file not found: \(path)"
        case let .configParseError(reason):
            return "Failed to parse configuration: \(reason)"

        case let .invalidArgument(arg, hint):
            if let hint = hint {
                return "Invalid argument: \(arg). \(hint)"
            }
            return "Invalid argument: \(arg)"
        case let .missingRequiredArgument(arg):
            return "Missing required argument: \(arg)"
        case let .invalidProviderValue(value):
            return "Invalid provider value: '\(value)'. Valid options: claude, codex, both, all"
        case let .invalidFormatValue(value):
            return "Invalid format value: '\(value)'. Valid options: text, json"

        case let .timeout(operation, seconds):
            return "Operation '\(operation)' timed out after \(String(format: "%.1f", seconds))s"
        case let .networkError(reason):
            return "Network error: \(reason)"
        case let .authenticationFailed(provider):
            return "Authentication failed for '\(provider)'. Please check your credentials."
        case let .noDataAvailable(provider):
            return "No data available for '\(provider)'. The service may be unavailable."

        case let .unknownCommand(cmd):
            return "Unknown command: '\(cmd)'. Run 'codexbar --help' for usage information."
        case let .internalError(reason):
            return "Internal error: \(reason)"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .providerNotFound, .providerNotSupported:
            return CLIExitCode.providerNotFound.rawValue
        case .configValidationFailed, .configFileNotFound, .configParseError:
            return CLIExitCode.configError.rawValue
        case .invalidArgument, .missingRequiredArgument, .invalidProviderValue, .invalidFormatValue:
            return CLIExitCode.parseError.rawValue
        case .timeout:
            return CLIExitCode.timeout.rawValue
        case .providerFetchFailed, .networkError, .authenticationFailed, .noDataAvailable:
            return CLIExitCode.generalError.rawValue
        case .unknownCommand:
            return CLIExitCode.generalError.rawValue
        case .internalError:
            return CLIExitCode.generalError.rawValue
        }
    }
}

// MARK: - Error Handling Helpers

public func handleError(_ error: Error, jsonOnly: Bool = false) {
    let cliError: CLIError
    if let error = error as? CLIError {
        cliError = error
    } else {
        cliError = .internalError(error.localizedDescription)
    }

    if !jsonOnly {
        fputs("Error: \(cliError.description)\n", stderr)
    }
}

public func exitWithError(_ error: Error, jsonOnly: Bool = false) -> Never {
    handleError(error, jsonOnly: jsonOnly)

    let exitCode: Int32
    if let cliError = error as? CLIError {
        exitCode = cliError.exitCode
    } else {
        exitCode = CLIExitCode.generalError.rawValue
    }

    exit(exitCode)
}

// MARK: - Validation Helpers

public func validateProvider(_ value: String) throws -> UsageProvider {
    guard let provider = ProviderDescriptorRegistry.cliNameMap[value.lowercased()] else {
        throw CLIError.invalidProviderValue(value)
    }
    return provider
}

public func validateFormat(_ value: String) throws -> OutputFormat {
    guard let format = OutputFormat(rawValue: value.lowercased()) else {
        throw CLIError.invalidFormatValue(value)
    }
    return format
}

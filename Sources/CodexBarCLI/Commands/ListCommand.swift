import CodexBarCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - List Command

public func runList(_ argv: [String]) {
    _ = parseGlobalOptions(argv)

    // Setup logging
    CodexBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: .error, json: false))

    // Parse list options
    var format: OutputFormat = .text
    var pretty = true

    var i = 0
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "-f", "--format":
            if i + 1 < argv.count {
                format = OutputFormat(rawValue: argv[i + 1]) ?? .text
                i += 2
            } else {
                i += 1
            }
        case "-j", "--json":
            format = .json
            i += 1
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

    // Load config
    let configStore = CodexBarConfigStore()
    let config: CodexBarConfig
    do {
        config = try configStore.loadOrCreateDefault()
    } catch {
        fputs("Error loading config: \(error.localizedDescription)\n", stderr)
        exit(CLIExitCode.configError.rawValue)
    }

    // Get enabled providers from config
    let enabledProviders = Set(config.enabledProviders())
    let allProviders = ProviderDescriptorRegistry.all.map { $0.id }

    switch format {
    case .text:
        outputListText(allProviders: allProviders, enabledProviders: enabledProviders)
    case .json:
        outputListJSON(allProviders: allProviders, enabledProviders: enabledProviders, pretty: pretty)
    }

    exit(CLIExitCode.success.rawValue)
}

// MARK: - Output

private func outputListText(allProviders: [UsageProvider], enabledProviders: Set<UsageProvider>) {
    print("Available providers:")
    print("")

    for provider in allProviders {
        let enabled = enabledProviders.contains(provider)
        let status = enabled ? "✓ enabled" : "✗ disabled"
        print("  \(provider.rawValue) - \(status)")
    }

    print("")
    print("Use 'codexbar usage --provider <id>' to query a specific provider")
}

private func outputListJSON(allProviders: [UsageProvider], enabledProviders: Set<UsageProvider>, pretty: Bool) {
    let payloads = allProviders.map { provider in
        ProviderListPayload(
            id: provider.rawValue,
            enabled: enabledProviders.contains(provider)
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]

    if let data = try? encoder.encode(payloads), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

// MARK: - Payload

private struct ProviderListPayload: Codable {
    let id: String
    let enabled: Bool
}

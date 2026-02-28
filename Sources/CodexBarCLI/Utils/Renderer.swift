import CodexBarCore
import Foundation

// MARK: - Usage Output

public func outputUsageText(results: [ProviderResult], jsonOnly: Bool) {
    var lines: [String] = []

    for result in results {
        if result.success, let usage = result.usage {
            lines.append("== \(result.provider.rawValue) ==")

            if let primary = usage.primary {
                lines.append("Primary: \(String(format: "%.1f", primary.usedPercent))% used")
                if let resetsAt = primary.resetsAt {
                    lines.append("Resets: \(resetsAt)")
                }
            }

            if let secondary = usage.secondary {
                lines.append("Secondary: \(String(format: "%.1f", secondary.usedPercent))% used")
            }

            if let identity = usage.identity, let email = identity.accountEmail {
                lines.append("Account: \(email)")
            }
        } else if let error = result.error {
            if !jsonOnly {
                lines.append("== \(result.provider.rawValue) ==")
                lines.append("Error: \(error.localizedDescription)")
            }
        }
    }

    if !lines.isEmpty {
        print(lines.joined(separator: "\n"))
    }
}

public func outputUsageJSON(results: [ProviderResult], pretty: Bool, jsonOnly: Bool) {
    let payloads = results.map { result -> ProviderPayload in
        ProviderPayload(
            provider: result.provider.rawValue,
            usedPercent: result.usage?.primary?.usedPercent,
            resetsAt: result.usage?.primary?.resetsAt,
            accountEmail: result.usage?.identity?.accountEmail,
            updatedAt: result.usage?.updatedAt ?? Date(),
            error: result.success ? nil : result.error?.localizedDescription
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    if let data = try? encoder.encode(payloads), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

// MARK: - Cost Output

public func outputCostText(results: [CostResult], jsonOnly: Bool) {
    var lines: [String] = []

    for result in results {
        if result.success, let snapshot = result.snapshot {
            lines.append("== \(result.provider.rawValue) Cost ==")

            if let sessionCost = snapshot.sessionCostUSD {
                lines.append("Session: $\(String(format: "%.2f", sessionCost))")
            }

            if let monthlyCost = snapshot.last30DaysCostUSD {
                lines.append("Last 30 days: $\(String(format: "%.2f", monthlyCost))")
            }
        } else if let error = result.error, !jsonOnly {
            lines.append("== \(result.provider.rawValue) ==")
            lines.append("Error: \(error.localizedDescription)")
        }
    }

    if !lines.isEmpty {
        print(lines.joined(separator: "\n"))
    }
}

public func outputCostJSON(results: [CostResult], pretty: Bool, jsonOnly: Bool) {
    let payloads = results.map { result -> CostPayload in
        CostPayload(
            provider: result.provider.rawValue,
            sessionCostUSD: result.snapshot?.sessionCostUSD,
            last30DaysCostUSD: result.snapshot?.last30DaysCostUSD,
            error: result.success ? nil : result.error?.localizedDescription
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    if let data = try? encoder.encode(payloads), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

import Foundation

public enum ZaiAPIRegion: String, CaseIterable, Sendable {
    case global
    case bigmodelCN = "bigmodel-cn"

    private static let quotaPath = "api/monitor/usage/quota/limit"

    public var displayName: String {
        switch self {
        case .global:
            return "Global (api.z.ai)"
        case .bigmodelCN:
            return "BigModel CN (open.bigmodel.cn)"
        }
    }

    public var baseURLString: String {
        switch self {
        case .global:
            return "https://api.z.ai"
        case .bigmodelCN:
            return "https://open.bigmodel.cn"
        }
    }

    public var quotaLimitURL: URL {
        URL(string: self.baseURLString)!.appendingPathComponent(Self.quotaPath)
    }
}

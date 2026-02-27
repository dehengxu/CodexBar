// Minimal SweetCookieKit stub for Swift 5.7 compatibility
import Foundation

// MARK: - Browser Types
public enum Browser: String, CaseIterable, Hashable, Sendable {
    case chrome, chromeBeta, chromeCanary, edge, edgeBeta, edgeCanary, brave, braveBeta, braveNightly, vivaldi, chromium, firefox, safari, arc, arcBeta, arcCanary, dia, chatgptAtlas, helium, zen

    public var displayName: String { rawValue.capitalized }
    public var basePath: String { NSHomeDirectory() + "/Library/Application Support/" + rawValue.capitalized }
    public static var defaultImportOrder: [Browser] { allCases }
    public static var safeStorageLabels: [(service: String, account: String)] { [] }
    public var usesGeckoProfileStore: Bool { self == .firefox }
    public var usesChromiumProfileStore: Bool { self != .safari && self != .firefox }
    public var appBundleName: String? { nil }
    public var chromiumProfileRelativePath: String? { nil }
    public var geckoProfilesFolder: String? { nil }
}

// MARK: - Cookie Types
public struct ChromiumCookieEntry: Sendable { public let host, name, value, path: String; public let expiresDate: Date?; public let isSecure, isHTTPOnly: Bool; public let sameSite: String }
public struct ChromiumLocalStorageEntry: Sendable { public let key, value, origin: String; public var rawValueLength: Int { value.count } }
public struct ChromiumLevelDBTextEntry: Sendable { public let key, value: String }

public enum ChromiumLocalStorageReader {
    public static func readEntries(from path: String, browser: Browser) -> [ChromiumLocalStorageEntry] { [] }
    public static func readTextEntries(from path: String, browser: Browser) -> [ChromiumLevelDBTextEntry] { [] }
    public static func readTokenCandidates(from path: String, browser: Browser) -> [String] { [] }

    // Add missing properties for compatibility
    public static func readEntries(_ path: String, browser: Browser) -> [ChromiumLocalStorageEntry] { [] }
    public static func readTextEntries(_ path: String, browser: Browser) -> [ChromiumLevelDBTextEntry] { [] }
    public static func readTokenCandidates(_ path: String, browser: Browser) -> [String] { [] }

    // URL-based methods for MiniMax compatibility (stub implementations return empty)
    public static func readEntries(for origin: String, in url: URL, logger: ((String) -> Void)?) -> [ChromiumLocalStorageEntry] { [] }
    public static func readTextEntries(in url: URL, logger: ((String) -> Void)?) -> [ChromiumLevelDBTextEntry] { [] }
    public static func readTokenCandidates(in url: URL, logger: ((String) -> Void)?) -> [String] { [] }
    public static func readTokenCandidates(in url: URL, minimumLength: Int, logger: ((String) -> Void)?) -> [String] { [] }
}

public enum ChromiumCookieImporter {
    public static func importCookies(from browser: Browser, domainFilter: String? = nil) -> [ChromiumCookieEntry] { [] }
    public static func stores(for browser: Browser) -> [String] { [] }
}

// MARK: - Keychain
public enum BrowserCookieKeychainAccessGate { public static var isDisabled: Bool = false }
public struct BrowserCookieKeychainPromptContext: Sendable { public let browser: Browser; public let reason: String; public var label: String { browser.displayName } }
public protocol BrowserCookieKeychainPromptHandler: AnyObject {
    static var handler: ((BrowserCookieKeychainPromptContext) -> Void)? { get set }
}

// MARK: - Cookie Models
public struct BrowserCookie: Sendable { public let browser: Browser; public let name, value, domain, path: String; public let expiresDate: Date?; public let isSecure: Bool }
public struct BrowserCookieRecord: Sendable { public let url, name, value, domain, path: String; public let expiresDate, expires, creationDate, lastAccessDate: Date?; public let isSecure, isHTTPOnly: Bool; public let sameSite: String?; public let store: String?; public var kind: BrowserCookieStoreKind { .primary } }
public struct BrowserCookieStoreRecords: Sendable { public let browser: Browser; public let profileLabel, url, labelPrefix, label: String; public let records: [BrowserCookieRecord]; public let store: String?; public var kind: BrowserCookieStoreKind { .primary } }
public typealias BrowserCookieImportOrder = [Browser]
public extension BrowserCookieImportOrder { var loginHint: String { first?.displayName ?? "browser" } }

// MARK: - Store Kind
public enum BrowserCookieStoreKind: Sendable {
    case network
    case primary
    case safari
}

// MARK: - Metadata
public struct BrowserMetadata: Sendable { public let browser: Browser; public let displayName: String; public let cookiePaths, localStoragePaths: [String]; public let safeStorageLabel: (service: String, account: String)?; public let browserCookieOrder: [Browser] }

public enum BrowserCatalog {
    public static var metadataByBrowser: [Browser: BrowserMetadata] { [:] }
    public static func metadata(for browser: Browser) -> BrowserMetadata? { nil }
}

// MARK: - Profile Locator
public struct ChromiumProfileRoot: Sendable {
    public let url: URL
    public let labelPrefix: String
}

public enum ChromiumProfileLocator {
    public static func roots(for browsers: [Browser], homeDirectories: [String]) -> [ChromiumProfileRoot] { [] }
}

// MARK: - Browser Cookie Client
public class BrowserCookieClient {
    public init() {}
    public static func defaultHomeDirectories() -> [String] { [NSHomeDirectory()] }
    public static func makeHTTPCookies(_ records: [Any], origin: String) -> [HTTPCookie] { [] }
    public var records: [BrowserCookieRecord] { [] }

    public func records(
        matching query: BrowserCookieQuery,
        in browser: Browser,
        logger: ((String) -> Void)? = nil) throws -> [BrowserCookieStoreRecords] {
        []
    }
}

// MARK: - Query
public struct BrowserCookieQuery: Sendable {
    public let domains: [String]
    public init(domains: [String]) { self.domains = domains }
    public var origin: String { domains.first ?? "" }
}

// MARK: - Error
public enum BrowserCookieError: Error, Sendable {
    case accessDenied, notFound, invalidData, unknown(String)
    public var accessDeniedHint: String? { nil }
    public var browser: Browser? { nil }
}

import CodexBarCore
import Foundation

extension SettingsStore {
    var bailianAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .bailian)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .bailian) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .bailian, field: "apiKey", value: newValue)
        }
    }

    var bailianCookieSource: ProviderCookieSource {
        get { self.resolvedCookieSource(provider: .bailian, fallback: .auto) }
        set {
            self.updateProviderConfig(provider: .bailian) { entry in
                entry.cookieSource = newValue
            }
            self.logProviderModeChange(provider: .bailian, field: "cookieSource", value: newValue.rawValue)
        }
    }

    var bailianCookieHeader: String {
        get { self.configSnapshot.providerConfig(for: .bailian)?.sanitizedCookieHeader ?? "" }
        set {
            self.updateProviderConfig(provider: .bailian) { entry in
                entry.cookieHeader = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .bailian, field: "cookieHeader", value: newValue)
        }
    }

    func ensureBailianAPITokenLoaded() {}

    func ensureBailianCookieLoaded() {}
}

extension SettingsStore {
    func bailianSettingsSnapshot(tokenOverride: TokenAccountOverride? = nil) -> ProviderSettingsSnapshot.BailianProviderSettings {
        ProviderSettingsSnapshot.BailianProviderSettings(
            apiRegion: nil,
            cookieSource: self.bailianSnapshotCookieSource(tokenOverride: tokenOverride),
            cookieHeader: self.bailianSnapshotCookieHeader(tokenOverride: tokenOverride))
    }

    private func bailianSnapshotCookieHeader(tokenOverride: TokenAccountOverride?) -> String {
        let fallback = self.bailianCookieHeader
        guard let support = TokenAccountSupportCatalog.support(for: .bailian),
              case .cookieHeader = support.injection
        else {
            return fallback
        }
        guard let account = ProviderTokenAccountSelection.selectedAccount(
            provider: .bailian,
            settings: self,
            override: tokenOverride)
        else {
            return fallback
        }
        return TokenAccountSupportCatalog.normalizedCookieHeader(account.token, support: support)
    }

    private func bailianSnapshotCookieSource(tokenOverride: TokenAccountOverride?) -> ProviderCookieSource {
        let fallback = self.bailianCookieSource
        guard let support = TokenAccountSupportCatalog.support(for: .bailian),
              support.requiresManualCookieSource
        else {
            return fallback
        }
        if self.tokenAccounts(for: .bailian).isEmpty { return fallback }
        return .manual
    }
}

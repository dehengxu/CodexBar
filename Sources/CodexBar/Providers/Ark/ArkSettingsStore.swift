import CodexBarCore
import Foundation

extension SettingsStore {
    var arkAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .ark)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .ark) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .ark, field: "apiKey", value: newValue)
        }
    }

    var arkCookieSource: ProviderCookieSource {
        get { self.resolvedCookieSource(provider: .ark, fallback: .auto) }
        set {
            self.updateProviderConfig(provider: .ark) { entry in
                entry.cookieSource = newValue
            }
            self.logProviderModeChange(provider: .ark, field: "cookieSource", value: newValue.rawValue)
        }
    }

    var arkCookieHeader: String {
        get { self.configSnapshot.providerConfig(for: .ark)?.sanitizedCookieHeader ?? "" }
        set {
            self.updateProviderConfig(provider: .ark) { entry in
                entry.cookieHeader = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .ark, field: "cookieHeader", value: newValue)
        }
    }

    var arkCurlCommand: String {
        get { self.configSnapshot.providerConfig(for: .ark)?.curlCommand ?? "" }
        set {
            self.updateProviderConfig(provider: .ark) { entry in
                entry.curlCommand = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .ark, field: "curlCommand", value: newValue)
        }
    }

    func ensureArkAPITokenLoaded() {}

    func ensureArkCookieLoaded() {}
}

extension SettingsStore {
    func arkSettingsSnapshot(tokenOverride: TokenAccountOverride? = nil) -> ProviderSettingsSnapshot.ArkProviderSettings {
        ProviderSettingsSnapshot.ArkProviderSettings(
            apiRegion: nil,
            cookieSource: self.arkSnapshotCookieSource(tokenOverride: tokenOverride),
            cookieHeader: self.arkSnapshotCookieHeader(tokenOverride: tokenOverride),
            curlCommand: self.arkCurlCommand)
    }

    private func arkSnapshotCookieHeader(tokenOverride: TokenAccountOverride?) -> String {
        let fallback = self.arkCookieHeader
        guard let support = TokenAccountSupportCatalog.support(for: .ark),
              case .cookieHeader = support.injection
        else {
            return fallback
        }
        guard let account = ProviderTokenAccountSelection.selectedAccount(
            provider: .ark,
            settings: self,
            override: tokenOverride)
        else {
            return fallback
        }
        return TokenAccountSupportCatalog.normalizedCookieHeader(account.token, support: support)
    }

    private func arkSnapshotCookieSource(tokenOverride: TokenAccountOverride?) -> ProviderCookieSource {
        let fallback = self.arkCookieSource
        guard let support = TokenAccountSupportCatalog.support(for: .ark),
              support.requiresManualCookieSource
        else {
            return fallback
        }
        if self.tokenAccounts(for: .ark).isEmpty { return fallback }
        return .manual
    }
}

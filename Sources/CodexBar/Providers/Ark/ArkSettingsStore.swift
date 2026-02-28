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

    func ensureArkAPITokenLoaded() {}
}

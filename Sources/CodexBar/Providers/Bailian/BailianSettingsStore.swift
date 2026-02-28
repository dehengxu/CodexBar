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

    func ensureBailianAPITokenLoaded() {}
}

import AppKit
import CodexBarCore
import Foundation
import SwiftUI

struct BailianProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .bailian

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.bailianAPIToken
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        _ = context
        return nil
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if BailianSettingsReader.apiToken(environment: context.environment) != nil {
            return true
        }
        context.settings.ensureBailianAPITokenLoaded()
        return !context.settings.bailianAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func settingsPickers(context: ProviderSettingsContext) -> [ProviderSettingsPickerDescriptor] {
        return []
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        _ = context
        return []
    }
}

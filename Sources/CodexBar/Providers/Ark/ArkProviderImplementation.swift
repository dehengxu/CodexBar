import AppKit
import CodexBarCore
import Foundation
import SwiftUI

struct ArkProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .ark

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.arkAPIToken
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        _ = context
        return nil
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if ArkSettingsReader.apiToken(environment: context.environment) != nil {
            return true
        }
        context.settings.ensureArkAPITokenLoaded()
        return !context.settings.arkAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

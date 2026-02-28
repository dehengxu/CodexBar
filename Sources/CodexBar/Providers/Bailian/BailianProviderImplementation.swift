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
        _ = settings.bailianCookieSource
        _ = settings.bailianCookieHeader
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        .bailian(context.settings.bailianSettingsSnapshot(tokenOverride: context.tokenOverride))
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
        let cookieBinding = Binding(
            get: { context.settings.bailianCookieSource.rawValue },
            set: { raw in
                context.settings.bailianCookieSource = ProviderCookieSource(rawValue: raw) ?? .auto
            })
        let cookieOptions = ProviderCookieSourceUI.options(
            allowsOff: true,
            keychainDisabled: context.settings.debugDisableKeychainAccess)

        let cookieSubtitle: () -> String? = {
            ProviderCookieSourceUI.subtitle(
                source: context.settings.bailianCookieSource,
                keychainDisabled: context.settings.debugDisableKeychainAccess,
                auto: "Automatic imports browser cookies.",
                manual: "Paste a Cookie header or cURL capture from Bailian settings.",
                off: "Bailian cookies are disabled.")
        }

        return [
            ProviderSettingsPickerDescriptor(
                id: "bailian-cookie-source",
                title: "Cookie source",
                subtitle: "Automatic imports browser cookies.",
                dynamicSubtitle: cookieSubtitle,
                binding: cookieBinding,
                options: cookieOptions,
                isVisible: nil,
                onChange: nil),
        ]
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "bailian-cookie",
                title: "",
                subtitle: "",
                kind: .secure,
                placeholder: "Cookie: …",
                binding: context.stringBinding(\.bailianCookieHeader),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "bailian-open-settings",
                        title: "Open Bailian Settings",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://bailian.console.aliyun.com/") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: { context.settings.bailianCookieSource == .manual },
                onActivate: { context.settings.ensureBailianCookieLoaded() }),
        ]
    }
}

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
        _ = settings.arkCookieSource
        _ = settings.arkCookieHeader
        _ = settings.arkCurlCommand
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        .ark(context.settings.arkSettingsSnapshot(tokenOverride: context.tokenOverride))
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
        let cookieBinding = Binding(
            get: { context.settings.arkCookieSource.rawValue },
            set: { raw in
                context.settings.arkCookieSource = ProviderCookieSource(rawValue: raw) ?? .auto
            })
        let cookieOptions = ProviderCookieSourceUI.options(
            allowsOff: true,
            keychainDisabled: context.settings.debugDisableKeychainAccess)

        let cookieSubtitle: () -> String? = {
            ProviderCookieSourceUI.subtitle(
                source: context.settings.arkCookieSource,
                keychainDisabled: context.settings.debugDisableKeychainAccess,
                auto: "Automatic imports browser cookies.",
                manual: "Paste a Cookie header or cURL command from ARK settings.",
                off: "ARK cookies are disabled.")
        }

        return [
            ProviderSettingsPickerDescriptor(
                id: "ark-cookie-source",
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
        var fields: [ProviderSettingsFieldDescriptor] = []

        // Curl command field
        fields.append(
            ProviderSettingsFieldDescriptor(
                id: "ark-curl-command",
                title: "Curl Command",
                subtitle: "Paste a full curl command to extract cookies and auth",
                kind: .secure,
                placeholder: "curl 'https://...' -H 'Cookie: ...'",
                binding: context.stringBinding(\.arkCurlCommand),
                actions: [],
                isVisible: nil,
                onActivate: nil))

        // Cookie field (shown when cookie source is manual)
        fields.append(
            ProviderSettingsFieldDescriptor(
                id: "ark-cookie",
                title: "",
                subtitle: "",
                kind: .secure,
                placeholder: "Cookie: …",
                binding: context.stringBinding(\.arkCookieHeader),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "ark-open-settings",
                        title: "Open ARK Settings",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://console.volcengine.com/ark") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: { context.settings.arkCookieSource == .manual },
                onActivate: { context.settings.ensureArkCookieLoaded() }))

        return fields
    }
}

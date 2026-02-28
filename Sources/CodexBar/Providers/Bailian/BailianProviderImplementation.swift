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
        _ = settings.bailianCurlCommand
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        .bailian(context.settings.bailianSettingsSnapshot(tokenOverride: context.tokenOverride))
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        // Check for API token in environment
        if BailianSettingsReader.apiToken(environment: context.environment) != nil {
            return true
        }
        // Check for API token in settings
        context.settings.ensureBailianAPITokenLoaded()
        if !context.settings.bailianAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        // Check for curl command
        let curlCommand = context.settings.bailianCurlCommand
        if !curlCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        // Check for cookie header (manual mode)
        let cookieHeader = context.settings.bailianCookieHeader
        if !cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
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
                manual: "Paste a Cookie header or cURL command from Bailian settings.",
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
        var fields: [ProviderSettingsFieldDescriptor] = []

        // Curl command field
        fields.append(
            ProviderSettingsFieldDescriptor(
                id: "bailian-curl-command",
                title: "Curl Command",
                subtitle: "Paste a full curl command to execute directly",
                kind: .secure,
                placeholder: "curl 'https://...' -H 'Cookie: ...'",
                binding: context.stringBinding(\.bailianCurlCommand),
                actions: [],
                isVisible: nil,
                onActivate: nil))

        // Cookie field (shown when cookie source is manual)
        fields.append(
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
                onActivate: { context.settings.ensureBailianCookieLoaded() }))

        return fields
    }
}

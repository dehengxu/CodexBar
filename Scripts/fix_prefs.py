#!/usr/bin/env python3
"""Complete fix for PreferencesDebugPane.swift Swift 5.7 compatibility"""

import re
from pathlib import Path

def fix_file():
    filepath = Path("/Users/dehengxu/Projects/3rd/vibecoding/CodexBar/Sources/CodexBar/PreferencesDebugPane.swift")
    content = filepath.read_text()

    # 1. Replace @Bindable with @ObservedObject
    content = content.replace('@Bindable var settings: SettingsStore', '@ObservedObject var settings: SettingsStore')
    content = content.replace('@Bindable var store: UsageStore', '@ObservedObject var store: UsageStore')

    # 2. Fix $settings.debugLogLevel - use Binding
    content = content.replace(
        'self.$settings.debugLogLevel',
        'Binding(get: { CodexBarLog.Level(rawValue: self.settings.defaultsState.debugLogLevelRaw) ?? .verbose }, set: { self.settings.defaultsState.debugLogLevelRaw = $0.rawValue })'
    )

    # 3. Fix $settings.debugKeepCLISessionsAlive - use Binding
    content = content.replace(
        'self.$settings.debugKeepCLISessionsAlive',
        'Binding(get: { self.settings.defaultsState.debugKeepCLISessionsAlive }, set: { self.settings.defaultsState.debugKeepCLISessionsAlive = $0 })'
    )

    # 4. Fix onChange syntax
    content = content.replace(
        '.onChange(of: self.debugFileLoggingEnabled) { _, newValue in',
        '.onChange(of: self.debugFileLoggingEnabled) { newValue in'
    )

    # 5. Remove .textSelection(.enabled)
    content = content.replace('.textSelection(.enabled)', '')

    # 6. Remove axis: .vertical from TextField
    content = content.replace('axis: .vertical', '')

    # 7. Fix switch expressions - add return statements
    content = re.sub(r'case \.cli: "cli"', 'case .cli:\n            return "cli"', content)
    content = re.sub(r'case \.web: "web"', 'case .web:\n            return "web"', content)
    content = re.sub(r'case \.oauth: "oauth"', 'case .oauth:\n            return "oauth"', content)
    content = re.sub(r'case \.apiToken: "api"', 'case .apiToken:\n            return "api"', content)
    content = re.sub(r'case \.localProbe: "local"', 'case .localProbe:\n            return "local"', content)
    content = re.sub(r'case \.webDashboard: "web"', 'case .webDashboard:\n            return "web"', content)

    # 8. Fix MainActor.run calls
    content = re.sub(
        r'await MainActor\.run \{\s*\n\s*self\.logText = text\s*\n\s*self\.isLoadingLog = false\s*\n\s*\}',
        'self.logText = text\n                self.isLoadingLog = false',
        content
    )
    content = content.replace('await MainActor.run { self.logText = text }', 'self.logText = text')

    filepath.write_text(content)
    print("Fixed!")

if __name__ == "__main__":
    fix_file()

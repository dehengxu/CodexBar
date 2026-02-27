import Foundation
import Combine

@MainActor
final class PreferencesSelection: ObservableObject {
    @Published var tab: PreferencesTab = .general
}

import Foundation

struct UserPreferences {
    var viewMode: UsageViewMode
    var isAutoRefreshEnabled: Bool
    var autoRefreshInterval: AutoRefreshInterval
    var isAlwaysOnTop: Bool
}

final class UserPreferencesStore {
    private enum Key {
        static let viewMode = "viewMode"
        static let isAutoRefreshEnabled = "isAutoRefreshEnabled"
        static let autoRefreshInterval = "autoRefreshInterval"
        static let isAlwaysOnTop = "isAlwaysOnTop"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserPreferences {
        UserPreferences(
            viewMode: loadViewMode(),
            isAutoRefreshEnabled: loadAutoRefreshEnabled(),
            autoRefreshInterval: loadAutoRefreshInterval(),
            isAlwaysOnTop: defaults.bool(forKey: Key.isAlwaysOnTop)
        )
    }

    func saveViewMode(_ viewMode: UsageViewMode) {
        defaults.set(viewMode.rawValue, forKey: Key.viewMode)
    }

    func saveAutoRefreshEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.isAutoRefreshEnabled)
    }

    func saveAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        defaults.set(interval.rawValue, forKey: Key.autoRefreshInterval)
    }

    func saveAlwaysOnTop(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.isAlwaysOnTop)
    }

    private func loadViewMode() -> UsageViewMode {
        guard let rawValue = defaults.string(forKey: Key.viewMode),
              let viewMode = UsageViewMode(rawValue: rawValue)
        else {
            return .simple
        }

        return viewMode
    }

    private func loadAutoRefreshEnabled() -> Bool {
        guard defaults.object(forKey: Key.isAutoRefreshEnabled) != nil else {
            return true
        }

        return defaults.bool(forKey: Key.isAutoRefreshEnabled)
    }

    private func loadAutoRefreshInterval() -> AutoRefreshInterval {
        guard defaults.object(forKey: Key.autoRefreshInterval) != nil else {
            return .oneMinute
        }

        let rawValue = defaults.double(forKey: Key.autoRefreshInterval)
        return AutoRefreshInterval(rawValue: rawValue) ?? .oneMinute
    }
}

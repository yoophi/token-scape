import CoreGraphics
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

        static func windowWidth(for viewMode: UsageViewMode) -> String {
            "windowWidth.\(viewMode.rawValue)"
        }

        static func windowHeight(for viewMode: UsageViewMode) -> String {
            "windowHeight.\(viewMode.rawValue)"
        }
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

    func loadWindowSize(for viewMode: UsageViewMode) -> CGSize? {
        let widthKey = Key.windowWidth(for: viewMode)
        let heightKey = Key.windowHeight(for: viewMode)

        guard defaults.object(forKey: widthKey) != nil,
              defaults.object(forKey: heightKey) != nil
        else {
            return nil
        }

        let width = defaults.double(forKey: widthKey)
        let height = defaults.double(forKey: heightKey)
        guard width > 0, height > 0 else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    func saveWindowSize(_ size: CGSize, for viewMode: UsageViewMode) {
        defaults.set(size.width, forKey: Key.windowWidth(for: viewMode))
        defaults.set(size.height, forKey: Key.windowHeight(for: viewMode))
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

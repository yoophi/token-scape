import CodexUsageCore
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var codexSnapshot: UsageSnapshot?
    @Published private(set) var codexError: String?
    @Published private(set) var claudeSnapshot: ClaudeUsageSnapshot?
    @Published private(set) var claudeError: String?
    @Published private(set) var lastRefresh: Date = .distantPast
    @Published private(set) var isLoading = false
    @Published private(set) var nextAutoRefreshAt: Date?
    @Published var now = Date()
    @Published var viewMode: UsageViewMode = .simple {
        didSet {
            preferencesStore.saveViewMode(viewMode)
            onViewModeChange?(viewMode)
        }
    }
    @Published var isAutoRefreshEnabled = true {
        didSet {
            preferencesStore.saveAutoRefreshEnabled(isAutoRefreshEnabled)
            configureRefreshTimer()
        }
    }
    @Published var autoRefreshInterval: AutoRefreshInterval = .oneMinute {
        didSet {
            preferencesStore.saveAutoRefreshInterval(autoRefreshInterval)
            configureRefreshTimer()
        }
    }
    @Published var isAlwaysOnTop = false {
        didSet {
            preferencesStore.saveAlwaysOnTop(isAlwaysOnTop)
            onAlwaysOnTopChange?(isAlwaysOnTop)
        }
    }

    private let preferencesStore: UserPreferencesStore
    private var tickTimer: Timer?
    private var refreshTimer: Timer?
    var onCodexChange: ((UsageSnapshot?) -> Void)?
    var onAlwaysOnTopChange: ((Bool) -> Void)?
    var onViewModeChange: ((UsageViewMode) -> Void)?

    var autoRefreshOption: AutoRefreshOption {
        get {
            AutoRefreshOption(isEnabled: isAutoRefreshEnabled, interval: autoRefreshInterval)
        }
        set {
            switch newValue {
            case .oneMinute:
                autoRefreshInterval = .oneMinute
                isAutoRefreshEnabled = true
            case .fiveMinutes:
                autoRefreshInterval = .fiveMinutes
                isAutoRefreshEnabled = true
            case .off:
                isAutoRefreshEnabled = false
            }
        }
    }

    init(preferencesStore: UserPreferencesStore = UserPreferencesStore()) {
        self.preferencesStore = preferencesStore
        let preferences = preferencesStore.load()
        viewMode = preferences.viewMode
        isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
        autoRefreshInterval = preferences.autoRefreshInterval
        isAlwaysOnTop = preferences.isAlwaysOnTop

        refresh()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        configureRefreshTimer()
    }

    func refresh() {
        guard !isLoading else {
            return
        }

        isLoading = true
        Task.detached(priority: .userInitiated) {
            let combined = UsageLoader.load()
            await MainActor.run {
                self.apply(combined)
            }
        }
    }

    private func apply(_ combined: UsageDashboardSnapshot) {
        codexSnapshot = combined.codex.value
        codexError = combined.codex.errorMessage
        claudeSnapshot = combined.claude.value
        claudeError = combined.claude.errorMessage
        lastRefresh = combined.loadedAt
        isLoading = false
        scheduleNextAutoRefresh()
        onCodexChange?(combined.codex.value)
    }

    private func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        nextAutoRefreshAt = nil

        guard isAutoRefreshEnabled else {
            return
        }

        scheduleNextAutoRefresh()
    }

    private func scheduleNextAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard isAutoRefreshEnabled else {
            nextAutoRefreshAt = nil
            return
        }

        let interval = autoRefreshInterval.rawValue
        nextAutoRefreshAt = Date().addingTimeInterval(interval)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
}

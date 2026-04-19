import CodexUsageCore
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var codexSnapshot: UsageSnapshot?
    @Published private(set) var codexError: String?
    @Published private(set) var claudeSnapshot: ClaudeUsageSnapshot?
    @Published private(set) var claudeError: String?
    @Published private(set) var claudeStatusMessage: String?
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

    private let loader: any UsageDashboardLoading
    private let scheduler: any RefreshScheduling
    private let preferencesStore: UserPreferencesStore
    var onCodexChange: ((UsageSnapshot?) -> Void)?
    var onClaudeChange: ((ClaudeUsageSnapshot?) -> Void)?
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

    init(
        loader: any UsageDashboardLoading,
        scheduler: any RefreshScheduling,
        preferencesStore: UserPreferencesStore = UserPreferencesStore()
    ) {
        self.loader = loader
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
        let preferences = preferencesStore.load()
        viewMode = preferences.viewMode
        isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
        autoRefreshInterval = preferences.autoRefreshInterval
        isAlwaysOnTop = preferences.isAlwaysOnTop

        refresh()
        scheduler.startTick { [weak self] in
            self?.now = Date()
        }
        configureRefreshTimer()
    }

    func refresh(forceRefresh: Bool = false) {
        guard !isLoading else {
            return
        }

        isLoading = true
        let loader = self.loader
        Task.detached(priority: .userInitiated) {
            let combined = loader.load(forceRefresh: forceRefresh)
            await MainActor.run {
                self.apply(combined)
            }
        }
    }

    private func apply(_ combined: UsageDashboardSnapshot) {
        if let codexValue = combined.codex.value {
            codexSnapshot = codexValue
        }
        codexError = combined.codex.errorMessage

        if let claudeValue = combined.claude.value {
            claudeSnapshot = claudeValue
            claudeStatusMessage = claudeValue.statusMessage
        }
        claudeError = combined.claude.errorMessage
        lastRefresh = combined.loadedAt
        isLoading = false
        scheduleNextAutoRefresh()
        onCodexChange?(codexSnapshot)
        onClaudeChange?(claudeSnapshot)
    }

    private func configureRefreshTimer() {
        scheduler.cancelRefresh()
        nextAutoRefreshAt = nil

        guard isAutoRefreshEnabled else {
            return
        }

        scheduleNextAutoRefresh()
    }

    private func scheduleNextAutoRefresh() {
        scheduler.cancelRefresh()

        guard isAutoRefreshEnabled else {
            nextAutoRefreshAt = nil
            return
        }

        let interval = autoRefreshInterval.rawValue
        nextAutoRefreshAt = Date().addingTimeInterval(interval)
        scheduler.scheduleRefresh(after: interval) { [weak self] in
            self?.refresh()
        }
    }
}

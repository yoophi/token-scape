import CodexUsageCore

enum UsageLoader {
    static func load() -> UsageDashboardSnapshot {
        LoadUsageDashboardUseCase().execute()
    }
}

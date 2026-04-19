import CodexUsageCore

protocol UsageDashboardLoading: Sendable {
    func load(forceRefresh: Bool) -> UsageDashboardSnapshot
}

struct LiveUsageLoader: UsageDashboardLoading, @unchecked Sendable {
    private let useCase: LoadUsageDashboardUseCase

    init(useCase: LoadUsageDashboardUseCase) {
        self.useCase = useCase
    }

    func load(forceRefresh: Bool) -> UsageDashboardSnapshot {
        useCase.execute(forceRefresh: forceRefresh)
    }
}

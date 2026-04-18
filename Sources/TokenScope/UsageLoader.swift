import CodexUsageCore

protocol UsageDashboardLoading: Sendable {
    func load() -> UsageDashboardSnapshot
}

struct LiveUsageLoader: UsageDashboardLoading, @unchecked Sendable {
    private let useCase: LoadUsageDashboardUseCase

    init(useCase: LoadUsageDashboardUseCase) {
        self.useCase = useCase
    }

    func load() -> UsageDashboardSnapshot {
        useCase.execute()
    }
}

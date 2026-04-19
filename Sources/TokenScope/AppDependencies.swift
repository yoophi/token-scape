import TokenScopeCore
import Foundation

@MainActor
struct AppDependencies {
    let store: UsageStore
    let preferencesStore: UserPreferencesStore

    static func live() -> AppDependencies {
        let preferencesStore = UserPreferencesStore()
        let loader = LiveUsageLoader(
            useCase: LoadUsageDashboardUseCase(
                codexReader: LocalCodexUsageLogAdapter(),
                claudeReader: LocalClaudeUsageLogAdapter(),
                clock: SystemClock()
            )
        )
        let scheduler = TimerRefreshScheduler()
        let store = UsageStore(
            loader: loader,
            scheduler: scheduler,
            preferencesStore: preferencesStore
        )

        return AppDependencies(store: store, preferencesStore: preferencesStore)
    }
}

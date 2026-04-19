import Foundation

public final class LoadUsageDashboardUseCase {
    private let codexReader: CodexUsageReading
    private let claudeReader: ClaudeUsageReading
    private let clock: DateProviding

    public init(
        codexReader: CodexUsageReading,
        claudeReader: ClaudeUsageReading,
        clock: DateProviding
    ) {
        self.codexReader = codexReader
        self.claudeReader = claudeReader
        self.clock = clock
    }

    public func execute(forceRefresh: Bool = false) -> UsageDashboardSnapshot {
        let now = clock.now
        return UsageDashboardSnapshot(
            codex: loadCodex(),
            claude: loadClaude(now: now, forceRefresh: forceRefresh),
            loadedAt: now
        )
    }

    private func loadCodex() -> UsageSource<UsageSnapshot> {
        do {
            return .loaded(try codexReader.latestSnapshot())
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func loadClaude(now: Date, forceRefresh: Bool) -> UsageSource<ClaudeUsageSnapshot> {
        do {
            return .loaded(try claudeReader.snapshot(now: now, forceRefresh: forceRefresh))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

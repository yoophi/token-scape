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

    public func execute() -> UsageDashboardSnapshot {
        let now = clock.now
        return UsageDashboardSnapshot(
            codex: loadCodex(),
            claude: loadClaude(now: now),
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

    private func loadClaude(now: Date) -> UsageSource<ClaudeUsageSnapshot> {
        do {
            return .loaded(try claudeReader.snapshot(now: now))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

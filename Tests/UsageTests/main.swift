import CodexUsageCore
import Foundation

private final class TestRunner {
    private var failures: [String] = []
    private var passed = 0

    func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            passed += 1
            print("✓ \(name)")
        } catch {
            failures.append("\(name): \(error)")
            print("✗ \(name)")
        }
    }

    func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw TestFailure(message)
        }
    }

    func finish() -> Int32 {
        if failures.isEmpty {
            print("\n\(passed) tests passed")
            return 0
        }

        print("")
        failures.forEach { print("FAIL: \($0)") }
        return 1
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private struct FixedClock: DateProviding {
    let now: Date
}

private struct StubCodexReader: CodexUsageReading {
    var snapshot: UsageSnapshot?
    var error: Error?

    func latestSnapshot() throws -> UsageSnapshot {
        if let error {
            throw error
        }

        guard let snapshot else {
            throw UsageReadError.noRateLimitEventsFound("<stub>")
        }

        return snapshot
    }
}

private struct StubClaudeReader: ClaudeUsageReading {
    var snapshot: ClaudeUsageSnapshot?
    var error: Error?

    func snapshot(now: Date) throws -> ClaudeUsageSnapshot {
        if let error {
            throw error
        }

        guard let snapshot else {
            throw ClaudeUsageReadError.projectsDirectoryNotFound("<stub>")
        }

        return snapshot
    }
}

private let now = Date(timeIntervalSince1970: 1_776_500_000)
private let codexSnapshot = UsageSnapshot(
    planType: "pro",
    primary: UsageSnapshot.Limit(usedPercent: 25, windowMinutes: 300, resetsAt: now.addingTimeInterval(3600)),
    secondary: nil,
    totalTokenUsage: nil,
    lastTokenUsage: nil,
    sourcePath: "/tmp/codex.jsonl",
    eventTimestamp: now,
    loadedAt: now
)
private let claudeSnapshot = ClaudeUsageSnapshot(
    fiveHourBlock: nil,
    weeklyBlock: nil,
    entryCount: 0,
    sourcePath: "/tmp/claude",
    loadedAt: now
)
private let runner = TestRunner()

runner.test("LoadUsageDashboardUseCase loads both sources independently") {
    let useCase = LoadUsageDashboardUseCase(
        codexReader: StubCodexReader(snapshot: codexSnapshot, error: nil),
        claudeReader: StubClaudeReader(snapshot: claudeSnapshot, error: nil),
        clock: FixedClock(now: now)
    )
    let result = useCase.execute()

    try runner.expect(result.loadedAt == now, "loadedAt should come from the injected clock")
    try runner.expect(result.codex.value == codexSnapshot, "codex snapshot should be loaded")
    try runner.expect(result.claude.value == claudeSnapshot, "claude snapshot should be loaded")
}

runner.test("LoadUsageDashboardUseCase preserves partial success") {
    let useCase = LoadUsageDashboardUseCase(
        codexReader: StubCodexReader(snapshot: codexSnapshot, error: nil),
        claudeReader: StubClaudeReader(snapshot: nil, error: ClaudeUsageReadError.projectsDirectoryNotFound("/missing")),
        clock: FixedClock(now: now)
    )
    let result = useCase.execute()

    try runner.expect(result.codex.value == codexSnapshot, "codex should still load when claude fails")
    try runner.expect(result.claude.errorMessage?.contains("/missing") == true, "claude error should be surfaced")
}

exit(runner.finish())

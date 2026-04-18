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

    func expectNotNil<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestFailure(message)
        }

        return value
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
private let usageLimitsJSON = """
{
  "five_hour": {
    "utilization": 35.0,
    "resets_at": "2026-04-19T03:00:00+00:00"
  },
  "seven_day": {
    "utilization": 14.0,
    "resets_at": "2026-04-25T20:00:00+00:00"
  },
  "seven_day_sonnet": {
    "utilization": 39.0,
    "resets_at": "2026-04-22T14:00:00+00:00"
  },
  "seven_day_opus": null,
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 100000,
    "used_credits": 12.5,
    "utilization": null
  }
}
"""
private let statuslineJSON = """
{
  "captured_at": "2026-04-19T00:00:00Z",
  "context_window": {
    "remaining_percentage": 82
  },
  "rate_limits": {
    "five_hour": {
      "used_percentage": 67.5,
      "resets_at": "2026-04-19T03:00:00+00:00"
    },
    "seven_day": {
      "used_percentage": 41,
      "resets_at": "2026-04-25T20:00:00+00:00"
    }
  }
}
"""
private let oauthUsageJSON = """
{
  "five_hour": {
    "utilization": 12.25,
    "resets_at": "2026-04-19T03:00:00.000Z"
  },
  "seven_day": {
    "utilization": 88,
    "resets_at": "2026-04-25T20:00:00.000Z"
  },
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": 50000,
    "used_credits": 0,
    "utilization": 0
  }
}
"""
private let oauthAccountJSON = """
{
  "memberships": [
    {
      "organization": {
        "billing_type": "stripe_subscription",
        "rate_limit_tier": "claude_max_5x"
      }
    }
  ]
}
"""

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

runner.test("ClaudeUsageLimitsCacheReader parses ccusage cache") {
    let reader = ClaudeUsageLimitsCacheReader(cacheURL: URL(fileURLWithPath: "/tmp/unused"))
    let limits = try runner.expectNotNil(reader.parse(usageLimitsJSON, sourcePath: "/tmp/usage-limits.json"), "limits should parse")

    try runner.expect(limits.source == .ccusageCache, "source should be ccusage cache")
    try runner.expect(limits.sourcePath == "/tmp/usage-limits.json", "source path should be preserved")
    try runner.expect(limits.fiveHour?.usedPercent == 35, "five hour utilization should parse")
    try runner.expect(limits.fiveHour?.remainingPercent == 65, "five hour remaining should be complement")
    try runner.expect(limits.sevenDay?.usedPercent == 14, "seven day utilization should parse")
    try runner.expect(limits.sevenDaySonnet?.usedPercent == 39, "sonnet utilization should parse")
    try runner.expect(limits.sevenDayOpus == nil, "null opus window should be nil")
    try runner.expect(limits.extraUsage?.isEnabled == true, "extra usage enabled should parse")
    try runner.expect(limits.extraUsage?.usedCredits == 12.5, "extra used credits should parse")
}

runner.test("ClaudeStatuslineCacheReader parses fresh statusline cache") {
    let reader = ClaudeStatuslineCacheReader(cacheURL: URL(fileURLWithPath: "/tmp/unused"), maximumAge: 15 * 60)
    let limits = try runner.expectNotNil(
        reader.parse(statuslineJSON, sourcePath: "/tmp/token-scope-status.json", now: ISO8601DateFormatter().date(from: "2026-04-19T00:05:00Z")!),
        "statusline limits should parse"
    )

    try runner.expect(limits.source == .statuslineCache, "source should be statusline cache")
    try runner.expect(limits.sourcePath == "/tmp/token-scope-status.json", "source path should be preserved")
    try runner.expect(limits.fiveHour?.usedPercent == 67.5, "five hour used percentage should parse")
    try runner.expect(limits.fiveHour?.remainingPercent == 32.5, "five hour remaining should be complement")
    try runner.expect(limits.sevenDay?.usedPercent == 41, "seven day used percentage should parse")
}

runner.test("ClaudeStatuslineCacheReader ignores stale statusline cache") {
    let reader = ClaudeStatuslineCacheReader(cacheURL: URL(fileURLWithPath: "/tmp/unused"), maximumAge: 60)
    let limits = reader.parse(
        statuslineJSON,
        sourcePath: "/tmp/token-scope-status.json",
        now: ISO8601DateFormatter().date(from: "2026-04-19T00:05:00Z")!
    )

    try runner.expect(limits == nil, "stale statusline cache should be ignored")
}

runner.test("ClaudeOAuthUsageReader parses usage and account responses") {
    let reader = ClaudeOAuthUsageReader(tokenProvider: { "unused" })
    let planName = reader.parsePlanName(oauthAccountJSON)
    let limits = try runner.expectNotNil(reader.parseUsage(oauthUsageJSON, planName: planName), "oauth limits should parse")

    try runner.expect(planName == "Max 5x", "plan name should parse from rate limit tier")
    try runner.expect(limits.source == .oauthAPI, "source should be oauth api")
    try runner.expect(limits.planName == "Max 5x", "plan name should be preserved")
    try runner.expect(limits.fiveHour?.usedPercent == 12.25, "five hour utilization should parse")
    try runner.expect(limits.sevenDay?.remainingPercent == 12, "seven day remaining should parse")
    try runner.expect(limits.extraUsage?.isEnabled == false, "extra usage enabled should parse")
}

exit(runner.finish())

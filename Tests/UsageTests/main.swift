import TokenScopeCore
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

    func snapshot(now: Date, forceRefresh: Bool) throws -> ClaudeUsageSnapshot {
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

private func temporaryDirectory(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("tokenscope-tests-\(UUID().uuidString)-\(name)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func httpResponse(
    status: Int,
    url: String = "https://api.anthropic.com/api/oauth/usage",
    headers: [String: String] = [:]
) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: headers)!
}

private func httpDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    return formatter.string(from: date)
}

private func jsonData(_ text: String) -> Data {
    text.data(using: .utf8)!
}

private func jsonDictionary(_ text: String) throws -> [String: Any] {
    guard let dictionary = try JSONSerialization.jsonObject(with: jsonData(text)) as? [String: Any] else {
        throw TestFailure("JSON dictionary expected")
    }

    return dictionary
}

private func cacheDateString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

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

runner.test("ClaudeOAuthUsageReader treats auth failures as manual refresh only") {
    for status in [401, 403] {
        let directory = try temporaryDirectory("oauth-auth-\(status)")
        defer { try? FileManager.default.removeItem(at: directory) }

        var calls = 0
        var tokenCalls = 0
        let reader = ClaudeOAuthUsageReader(
            cacheURL: directory.appendingPathComponent("token-scope-oauth-usage.json"),
            tokenProvider: {
                tokenCalls += 1
                return "token"
            },
            freshCacheAge: 0,
            retryInterval: 300,
            httpPerform: { _ in
                calls += 1
                return (nil, httpResponse(status: status), nil)
            }
        )

        let first = reader.loadWithStatus(now: now)
        let second = reader.loadWithStatus(now: now.addingTimeInterval(60))
        let forced = reader.loadWithStatus(now: now.addingTimeInterval(61), forceRefresh: true)

        try runner.expect(first.limits == nil, "auth failure should not produce fresh limits")
        try runner.expect(first.statusMessage?.contains("재인증 필요") == true, "auth failure should request re-auth")
        try runner.expect(second.statusMessage?.contains("재인증 필요") == true, "stored auth failure should remain manual")
        try runner.expect(calls == 2, "non-force retry should be skipped, force refresh should call API")
        try runner.expect(tokenCalls == 2, "non-force manual-refresh state should skip token lookup")
        try runner.expect(forced.statusMessage?.contains("재인증 필요") == true, "forced auth failure should still request re-auth")
    }
}

runner.test("ClaudeOAuthUsageReader honors numeric and HTTP-date retry-after") {
    let numericDirectory = try temporaryDirectory("oauth-429-numeric")
    defer { try? FileManager.default.removeItem(at: numericDirectory) }

    var numericCalls = 0
    let numericReader = ClaudeOAuthUsageReader(
        cacheURL: numericDirectory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: { "token" },
        freshCacheAge: 0,
        retryInterval: 300,
        httpPerform: { _ in
            numericCalls += 1
            return (nil, httpResponse(status: 429, headers: ["Retry-After": "30"]), nil)
        }
    )

    _ = numericReader.loadWithStatus(now: now)
    let skipped = numericReader.loadWithStatus(now: now.addingTimeInterval(29))
    _ = numericReader.loadWithStatus(now: now.addingTimeInterval(31))

    try runner.expect(numericCalls == 2, "numeric Retry-After should skip requests until the delay passes")
    try runner.expect(skipped.statusMessage?.contains("후 재시도") == true, "skipped retry should explain the delay")

    let dateDirectory = try temporaryDirectory("oauth-429-date")
    defer { try? FileManager.default.removeItem(at: dateDirectory) }

    var dateCalls = 0
    let dateReader = ClaudeOAuthUsageReader(
        cacheURL: dateDirectory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: { "token" },
        freshCacheAge: 0,
        retryInterval: 300,
        httpPerform: { _ in
            dateCalls += 1
            return (nil, httpResponse(status: 429, headers: ["Retry-After": httpDate(Date().addingTimeInterval(30))]), nil)
        }
    )

    _ = dateReader.loadWithStatus(now: now)
    _ = dateReader.loadWithStatus(now: now.addingTimeInterval(20))

    try runner.expect(dateCalls == 1, "HTTP-date Retry-After should also skip early automatic retries")
}

runner.test("ClaudeOAuthUsageReader uses default retry interval for server and transport failures") {
    let directory = try temporaryDirectory("oauth-retry-default")
    defer { try? FileManager.default.removeItem(at: directory) }

    var calls = 0
    let reader = ClaudeOAuthUsageReader(
        cacheURL: directory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: { "token" },
        freshCacheAge: 0,
        retryInterval: 120,
        httpPerform: { _ in
            calls += 1
            return (nil, httpResponse(status: 500), nil)
        }
    )

    _ = reader.loadWithStatus(now: now)
    _ = reader.loadWithStatus(now: now.addingTimeInterval(60))
    _ = reader.loadWithStatus(now: now.addingTimeInterval(121))

    try runner.expect(calls == 2, "server failures should wait for the configured retry interval")
}

runner.test("ClaudeOAuthUsageReader surfaces offline transport status") {
    let directory = try temporaryDirectory("oauth-offline")
    defer { try? FileManager.default.removeItem(at: directory) }

    let reader = ClaudeOAuthUsageReader(
        cacheURL: directory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: { "token" },
        freshCacheAge: 0,
        retryInterval: 120,
        httpPerform: { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }
    )

    let result = reader.loadWithStatus(now: now)

    try runner.expect(result.statusMessage?.contains("offline") == true, "offline transport failures should be identifiable")
}

runner.test("ClaudeOAuthUsageReader uses fresh plan cache without account request") {
    let directory = try temporaryDirectory("oauth-plan-cache")
    defer { try? FileManager.default.removeItem(at: directory) }

    let planCacheURL = directory.appendingPathComponent("token-scope-oauth-plan.json")
    let planPayload: [String: Any] = [
        "captured_at": cacheDateString(now),
        "plan_name": "Max 5x"
    ]
    try JSONSerialization.data(withJSONObject: planPayload).write(to: planCacheURL)

    var accountCalls = 0
    let reader = ClaudeOAuthUsageReader(
        cacheURL: directory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: { "token" },
        freshCacheAge: 0,
        httpPerform: { request in
            if request.url?.path.contains("/account") == true {
                accountCalls += 1
                return (nil, httpResponse(status: 500, url: request.url!.absoluteString), nil)
            }

            return (jsonData(oauthUsageJSON), httpResponse(status: 200, url: request.url!.absoluteString), nil)
        }
    )

    let result = reader.loadWithStatus(now: now)

    try runner.expect(result.limits?.planName == "Max 5x", "fresh plan cache should be used")
    try runner.expect(accountCalls == 0, "fresh plan cache should avoid account API calls")
}

runner.test("ClaudeOAuthUsageReader preserves existing plan when account lookup fails") {
    let directory = try temporaryDirectory("oauth-plan-fallback")
    defer { try? FileManager.default.removeItem(at: directory) }

    let cacheURL = directory.appendingPathComponent("token-scope-oauth-usage.json")
    let usagePayload: [String: Any] = [
        "captured_at": cacheDateString(now.addingTimeInterval(-600)),
        "plan_name": "Max 20x",
        "usage": try jsonDictionary(oauthUsageJSON)
    ]
    try JSONSerialization.data(withJSONObject: usagePayload).write(to: cacheURL)

    let reader = ClaudeOAuthUsageReader(
        cacheURL: cacheURL,
        tokenProvider: { "token" },
        freshCacheAge: 0,
        httpPerform: { request in
            if request.url?.path.contains("/account") == true {
                return (nil, httpResponse(status: 500, url: request.url!.absoluteString), nil)
            }

            return (jsonData(oauthUsageJSON), httpResponse(status: 200, url: request.url!.absoluteString), nil)
        }
    )

    let result = reader.loadWithStatus(now: now)

    try runner.expect(result.limits?.planName == "Max 20x", "existing cached plan should survive account lookup failures")
}

runner.test("ClaudeOAuthUsageReader stores token failures as manual refresh only") {
    let directory = try temporaryDirectory("oauth-token-failure")
    defer { try? FileManager.default.removeItem(at: directory) }

    var tokenCalls = 0
    var networkCalls = 0
    let reader = ClaudeOAuthUsageReader(
        cacheURL: directory.appendingPathComponent("token-scope-oauth-usage.json"),
        tokenProvider: {
            tokenCalls += 1
            throw ClaudeOAuthUsageError.tokenNotFound
        },
        freshCacheAge: 0,
        httpPerform: { _ in
            networkCalls += 1
            return (nil, httpResponse(status: 200), nil)
        }
    )

    let first = reader.loadWithStatus(now: now)
    let second = reader.loadWithStatus(now: now.addingTimeInterval(60))

    try runner.expect(first.statusMessage?.contains("토큰 없음") == true, "missing token should be surfaced")
    try runner.expect(second.statusMessage?.contains("토큰 없음") == true, "stored token failure should be reused")
    try runner.expect(tokenCalls == 1, "stored manual-refresh token failure should skip token lookup")
    try runner.expect(networkCalls == 0, "token failures should not call the API")
}

runner.test("ClaudeUsageBlockComputer splits entries on window boundaries") {
    let start = Date(timeIntervalSince1970: 1_000)
    let entries = [
        ClaudeUsageEntry(id: "1", timestamp: start, model: "claude", inputTokens: 1, outputTokens: 1, cacheCreationTokens: 0, cacheReadTokens: 0),
        ClaudeUsageEntry(id: "2", timestamp: start.addingTimeInterval(50), model: "claude", inputTokens: 2, outputTokens: 2, cacheCreationTokens: 0, cacheReadTokens: 0),
        ClaudeUsageEntry(id: "3", timestamp: start.addingTimeInterval(150), model: "claude", inputTokens: 3, outputTokens: 3, cacheCreationTokens: 0, cacheReadTokens: 0)
    ]

    let blocks = ClaudeUsageBlockComputer.computeBlocks(entries: entries, window: 100)

    try runner.expect(blocks.count == 2, "entries should split into two blocks")
    try runner.expect(blocks[0].messageCount == 2, "first block should contain first two entries")
    try runner.expect(blocks[1].messageCount == 1, "second block should contain final entry")
    try runner.expect(ClaudeUsageBlockComputer.currentBlock(entries: entries, window: 100, now: start.addingTimeInterval(175))?.messageCount == 1, "current block should be selected by now")
}

exit(runner.finish())

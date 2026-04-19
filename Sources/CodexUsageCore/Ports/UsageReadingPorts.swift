import Foundation

public protocol CodexUsageReading {
    func latestSnapshot() throws -> UsageSnapshot
}

public protocol ClaudeUsageReading {
    func snapshot(now: Date, forceRefresh: Bool) throws -> ClaudeUsageSnapshot
}

public protocol DateProviding {
    var now: Date { get }
}

public struct SystemClock: DateProviding {
    public init() {}

    public var now: Date {
        Date()
    }
}

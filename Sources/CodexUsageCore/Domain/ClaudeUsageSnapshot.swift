import Foundation

public struct ClaudeUsageEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int

    public init(
        id: String,
        timestamp: Date,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

public struct ClaudeUsageBlock: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public var entries: [ClaudeUsageEntry]

    public init(start: Date, end: Date, entries: [ClaudeUsageEntry]) {
        self.start = start
        self.end = end
        self.entries = entries
    }

    public var totalTokens: Int { entries.reduce(0) { $0 + $1.totalTokens } }
    public var inputTokens: Int { entries.reduce(0) { $0 + $1.inputTokens } }
    public var outputTokens: Int { entries.reduce(0) { $0 + $1.outputTokens } }
    public var cacheCreationTokens: Int { entries.reduce(0) { $0 + $1.cacheCreationTokens } }
    public var cacheReadTokens: Int { entries.reduce(0) { $0 + $1.cacheReadTokens } }
    public var messageCount: Int { entries.count }

    public func isActive(at now: Date) -> Bool {
        end > now
    }

    public func timeRemaining(from now: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }
}

public struct ClaudeUsageSnapshot: Equatable, Sendable {
    public let fiveHourBlock: ClaudeUsageBlock?
    public let weeklyBlock: ClaudeUsageBlock?
    public let entryCount: Int
    public let sourcePath: String
    public let loadedAt: Date

    public init(
        fiveHourBlock: ClaudeUsageBlock?,
        weeklyBlock: ClaudeUsageBlock?,
        entryCount: Int,
        sourcePath: String,
        loadedAt: Date = Date()
    ) {
        self.fiveHourBlock = fiveHourBlock
        self.weeklyBlock = weeklyBlock
        self.entryCount = entryCount
        self.sourcePath = sourcePath
        self.loadedAt = loadedAt
    }
}

public enum ClaudeUsageReadError: LocalizedError, Equatable {
    case projectsDirectoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .projectsDirectoryNotFound(let path):
            return "Claude projects directory was not found: \(path)"
        }
    }
}

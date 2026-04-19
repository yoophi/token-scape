import Foundation

public struct UsageSnapshot: Equatable, Sendable {
    public struct TokenUsage: Equatable, Sendable {
        public let inputTokens: Int
        public let cachedInputTokens: Int
        public let outputTokens: Int
        public let reasoningOutputTokens: Int
        public let totalTokens: Int

        public init(
            inputTokens: Int,
            cachedInputTokens: Int,
            outputTokens: Int,
            reasoningOutputTokens: Int,
            totalTokens: Int
        ) {
            self.inputTokens = inputTokens
            self.cachedInputTokens = cachedInputTokens
            self.outputTokens = outputTokens
            self.reasoningOutputTokens = reasoningOutputTokens
            self.totalTokens = totalTokens
        }
    }

    public struct Limit: Equatable, Sendable {
        public let usedPercent: Double
        public let windowMinutes: Int?
        public let resetsAt: Date?

        public init(usedPercent: Double, windowMinutes: Int?, resetsAt: Date?) {
            self.usedPercent = usedPercent
            self.windowMinutes = windowMinutes
            self.resetsAt = resetsAt
        }

        public var remainingPercent: Double {
            max(0, min(100, 100 - usedPercent))
        }
    }

    public let planType: String?
    public let primary: Limit?
    public let secondary: Limit?
    public let totalTokenUsage: TokenUsage?
    public let lastTokenUsage: TokenUsage?
    public let sourcePath: String
    public let eventTimestamp: Date?
    public let loadedAt: Date

    public init(
        planType: String?,
        primary: Limit?,
        secondary: Limit?,
        totalTokenUsage: TokenUsage? = nil,
        lastTokenUsage: TokenUsage? = nil,
        sourcePath: String,
        eventTimestamp: Date?,
        loadedAt: Date = Date()
    ) {
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.totalTokenUsage = totalTokenUsage
        self.lastTokenUsage = lastTokenUsage
        self.sourcePath = sourcePath
        self.eventTimestamp = eventTimestamp
        self.loadedAt = loadedAt
    }
}

public enum UsageReadError: LocalizedError, Equatable {
    case sessionsDirectoryNotFound(String)
    case noRateLimitEventsFound(String)

    public var errorDescription: String? {
        switch self {
        case .sessionsDirectoryNotFound(let path):
            return "Codex session directory was not found: \(path)"
        case .noRateLimitEventsFound(let path):
            return "No rate limit events were found under: \(path)"
        }
    }
}

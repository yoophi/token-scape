import Foundation

public struct UsageDashboardSnapshot: Sendable {
    public let codex: UsageSource<UsageSnapshot>
    public let claude: UsageSource<ClaudeUsageSnapshot>
    public let loadedAt: Date

    public init(
        codex: UsageSource<UsageSnapshot>,
        claude: UsageSource<ClaudeUsageSnapshot>,
        loadedAt: Date
    ) {
        self.codex = codex
        self.claude = claude
        self.loadedAt = loadedAt
    }
}

public enum UsageSource<Value: Sendable>: Sendable {
    case loaded(Value)
    case failed(String)

    public var value: Value? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }

    public var errorMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

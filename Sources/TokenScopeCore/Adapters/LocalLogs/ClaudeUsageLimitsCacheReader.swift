import Foundation

public struct ClaudeUsageLimitsCacheReader {
    private let fileManager: FileManager
    private let cacheURL: URL

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.cacheURL = claudeHome.appendingPathComponent("usage-limits.json")
    }

    public init(cacheURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.cacheURL = cacheURL
    }

    public func load() -> ClaudeUsageLimits? {
        guard fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data)
        else {
            return nil
        }

        return ClaudeUsageLimits(
            source: .ccusageCache,
            sourcePath: cacheURL.path,
            fiveHour: parseWindow(json["five_hour"]),
            sevenDay: parseWindow(json["seven_day"]),
            sevenDaySonnet: parseWindow(json["seven_day_sonnet"]),
            sevenDayOpus: parseWindow(json["seven_day_opus"]),
            extraUsage: parseExtraUsage(json["extra_usage"])
        )
    }

    public func parse(_ text: String, sourcePath: String = "<memory>") -> ClaudeUsageLimits? {
        guard let json = ClaudeUsageLimitParsing.jsonDictionary(from: text) else {
            return nil
        }

        return ClaudeUsageLimits(
            source: .ccusageCache,
            sourcePath: sourcePath,
            fiveHour: parseWindow(json["five_hour"]),
            sevenDay: parseWindow(json["seven_day"]),
            sevenDaySonnet: parseWindow(json["seven_day_sonnet"]),
            sevenDayOpus: parseWindow(json["seven_day_opus"]),
            extraUsage: parseExtraUsage(json["extra_usage"])
        )
    }

    private func parseWindow(_ value: Any?) -> ClaudeUsageLimits.Window? {
        guard let dictionary = value as? [String: Any],
              let utilization = ClaudeUsageLimitParsing.number(dictionary["utilization"])
        else {
            return nil
        }

        return ClaudeUsageLimits.Window(
            usedPercent: utilization,
            resetsAt: ClaudeUsageLimitParsing.date(dictionary["resets_at"] as? String)
        )
    }

    private func parseExtraUsage(_ value: Any?) -> ClaudeUsageLimits.ExtraUsage? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        return ClaudeUsageLimits.ExtraUsage(
            isEnabled: ClaudeUsageLimitParsing.bool(dictionary["is_enabled"]) ?? false,
            monthlyLimit: ClaudeUsageLimitParsing.number(dictionary["monthly_limit"]),
            usedCredits: ClaudeUsageLimitParsing.number(dictionary["used_credits"]),
            utilization: ClaudeUsageLimitParsing.number(dictionary["utilization"])
        )
    }
}

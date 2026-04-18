import Foundation

public struct ClaudeStatuslineCacheReader {
    private let fileManager: FileManager
    private let cacheURL: URL
    private let maximumAge: TimeInterval?

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        fileManager: FileManager = .default,
        maximumAge: TimeInterval? = 15 * 60
    ) {
        self.fileManager = fileManager
        self.cacheURL = claudeHome.appendingPathComponent("token-scope-status.json")
        self.maximumAge = maximumAge
    }

    public init(cacheURL: URL, fileManager: FileManager = .default, maximumAge: TimeInterval? = 15 * 60) {
        self.fileManager = fileManager
        self.cacheURL = cacheURL
        self.maximumAge = maximumAge
    }

    public func load(now: Date = Date()) -> ClaudeUsageLimits? {
        guard fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data)
        else {
            return nil
        }

        return parse(json, sourcePath: cacheURL.path, now: now)
    }

    public func parse(_ text: String, sourcePath: String = "<memory>", now: Date = Date()) -> ClaudeUsageLimits? {
        guard let json = ClaudeUsageLimitParsing.jsonDictionary(from: text) else {
            return nil
        }

        return parse(json, sourcePath: sourcePath, now: now)
    }

    private func parse(_ json: [String: Any], sourcePath: String, now: Date) -> ClaudeUsageLimits? {
        if let maximumAge,
           let capturedAt = capturedAt(json),
           now.timeIntervalSince(capturedAt) > maximumAge {
            return nil
        }

        let rateLimits = json["rate_limits"] as? [String: Any]
        let fiveHour = parseWindow(rateLimits?["five_hour"])
        let sevenDay = parseWindow(rateLimits?["seven_day"])

        guard fiveHour != nil || sevenDay != nil else {
            return nil
        }

        return ClaudeUsageLimits(
            source: .statuslineCache,
            sourcePath: sourcePath,
            fiveHour: fiveHour,
            sevenDay: sevenDay
        )
    }

    private func capturedAt(_ json: [String: Any]) -> Date? {
        ClaudeUsageLimitParsing.date(json["captured_at"] as? String)
            ?? ClaudeUsageLimitParsing.date(json["timestamp"] as? String)
    }

    private func parseWindow(_ value: Any?) -> ClaudeUsageLimits.Window? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        let usedPercent = ClaudeUsageLimitParsing.number(dictionary["used_percentage"])
            ?? ClaudeUsageLimitParsing.number(dictionary["utilization"])
        guard let usedPercent else {
            return nil
        }

        return ClaudeUsageLimits.Window(
            usedPercent: usedPercent,
            resetsAt: ClaudeUsageLimitParsing.date(dictionary["resets_at"] as? String)
                ?? ClaudeUsageLimitParsing.date(dictionary["reset_at"] as? String)
        )
    }
}

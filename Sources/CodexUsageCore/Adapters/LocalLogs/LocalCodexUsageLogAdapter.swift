import Foundation

public typealias CodexUsageReader = LocalCodexUsageLogAdapter

public final class LocalCodexUsageLogAdapter: CodexUsageReading {
    private let fileManager: FileManager
    private let sessionsDirectory: URL
    private let maxFilesToScan: Int

    public init(
        codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        fileManager: FileManager = .default,
        maxFilesToScan: Int = 200
    ) {
        self.fileManager = fileManager
        self.sessionsDirectory = codexHome.appendingPathComponent("sessions")
        self.maxFilesToScan = maxFilesToScan
    }

    public func latestSnapshot() throws -> UsageSnapshot {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sessionsDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw UsageReadError.sessionsDirectoryNotFound(sessionsDirectory.path)
        }

        let candidates = try sessionFiles()
        for file in candidates.prefix(maxFilesToScan) {
            if let snapshot = try snapshot(from: file) {
                return snapshot
            }
        }

        throw UsageReadError.noRateLimitEventsFound(sessionsDirectory.path)
    }

    public func snapshot(from file: URL) throws -> UsageSnapshot? {
        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.split(whereSeparator: \.isNewline).reversed()

        for line in lines {
            guard line.contains("rate_limits"),
                  let data = String(line).data(using: .utf8),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = root["payload"] as? [String: Any],
                  let rateLimits = payload["rate_limits"] as? [String: Any]
            else {
                continue
            }

            return UsageSnapshot(
                planType: rateLimits["plan_type"] as? String,
                primary: parseLimit(rateLimits["primary"]),
                secondary: parseLimit(rateLimits["secondary"]),
                totalTokenUsage: parseTokenUsage(payload, key: "total_token_usage"),
                lastTokenUsage: parseTokenUsage(payload, key: "last_token_usage"),
                sourcePath: file.path,
                eventTimestamp: parseTimestamp(root["timestamp"] as? String)
            )
        }

        return nil
    }

    private func sessionFiles() throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(url)
            }
        }

        return files.sorted { lhs, rhs in
            modificationDate(lhs) > modificationDate(rhs)
        }
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func parseLimit(_ value: Any?) -> UsageSnapshot.Limit? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = number(dictionary["used_percent"])
        else {
            return nil
        }

        return UsageSnapshot.Limit(
            usedPercent: usedPercent,
            windowMinutes: number(dictionary["window_minutes"]).map(Int.init),
            resetsAt: number(dictionary["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        )
    }

    private func parseTokenUsage(_ payload: [String: Any], key: String) -> UsageSnapshot.TokenUsage? {
        guard let info = payload["info"] as? [String: Any],
              let usage = info[key] as? [String: Any],
              let totalTokens = number(usage["total_tokens"])
        else {
            return nil
        }

        return UsageSnapshot.TokenUsage(
            inputTokens: Int(number(usage["input_tokens"]) ?? 0),
            cachedInputTokens: Int(number(usage["cached_input_tokens"]) ?? 0),
            outputTokens: Int(number(usage["output_tokens"]) ?? 0),
            reasoningOutputTokens: Int(number(usage["reasoning_output_tokens"]) ?? 0),
            totalTokens: Int(totalTokens)
        )
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private func parseTimestamp(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

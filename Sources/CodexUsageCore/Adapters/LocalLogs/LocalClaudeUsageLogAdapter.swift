import Foundation

public typealias ClaudeUsageReader = LocalClaudeUsageLogAdapter

public final class LocalClaudeUsageLogAdapter: ClaudeUsageReading {
    private let fileManager: FileManager
    private let projectsDirectory: URL

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.projectsDirectory = claudeHome.appendingPathComponent("projects")
    }

    public func snapshot(now: Date = Date()) throws -> ClaudeUsageSnapshot {
        let entries = try loadEntries()
        return ClaudeUsageSnapshot(
            fiveHourBlock: currentBlock(entries: entries, window: 5 * 3600, now: now),
            weeklyBlock: currentBlock(entries: entries, window: 7 * 24 * 3600, now: now),
            entryCount: entries.count,
            sourcePath: projectsDirectory.path
        )
    }

    public func loadEntries() throws -> [ClaudeUsageEntry] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: projectsDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ClaudeUsageReadError.projectsDirectoryNotFound(projectsDirectory.path)
        }

        var seen = Set<String>()
        var entries: [ClaudeUsageEntry] = []

        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            for entry in parseFile(url) where seen.insert(entry.id).inserted {
                entries.append(entry)
            }
        }

        entries.sort { $0.timestamp < $1.timestamp }
        return entries
    }

    public func parseFile(_ url: URL) -> [ClaudeUsageEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        var entries: [ClaudeUsageEntry] = []
        for rawLine in content.split(whereSeparator: \.isNewline) {
            guard let lineData = String(rawLine).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  (json["type"] as? String) == "assistant",
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let timestampString = json["timestamp"] as? String,
                  let timestamp = parseDate(timestampString)
            else {
                continue
            }

            let input = int(usage["input_tokens"])
            let output = int(usage["output_tokens"])
            let cacheCreate = int(usage["cache_creation_input_tokens"])
            let cacheRead = int(usage["cache_read_input_tokens"])

            guard input + output + cacheCreate + cacheRead > 0 else {
                continue
            }

            let uuid = (json["uuid"] as? String) ?? UUID().uuidString
            let messageId = (message["id"] as? String) ?? ""
            let dedupeKey = messageId.isEmpty ? uuid : "\(messageId):\(uuid)"

            entries.append(ClaudeUsageEntry(
                id: dedupeKey,
                timestamp: timestamp,
                model: (message["model"] as? String) ?? "unknown",
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreate,
                cacheReadTokens: cacheRead
            ))
        }

        return entries
    }

    public func computeBlocks(entries: [ClaudeUsageEntry], window: TimeInterval) -> [ClaudeUsageBlock] {
        guard !entries.isEmpty else {
            return []
        }

        var blocks: [ClaudeUsageBlock] = []
        var start = entries[0].timestamp
        var bucket: [ClaudeUsageEntry] = []

        for entry in entries {
            let end = start.addingTimeInterval(window)
            if entry.timestamp < end {
                bucket.append(entry)
            } else {
                if !bucket.isEmpty {
                    blocks.append(ClaudeUsageBlock(start: start, end: end, entries: bucket))
                }
                start = entry.timestamp
                bucket = [entry]
            }
        }

        if !bucket.isEmpty {
            blocks.append(ClaudeUsageBlock(start: start, end: start.addingTimeInterval(window), entries: bucket))
        }

        return blocks
    }

    public func currentBlock(entries: [ClaudeUsageEntry], window: TimeInterval, now: Date = Date()) -> ClaudeUsageBlock? {
        computeBlocks(entries: entries, window: window).last { $0.isActive(at: now) }
    }

    private func int(_ value: Any?) -> Int {
        switch value {
        case let value as Int:
            return value
        case let value as Double:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value) ?? 0
        default:
            return 0
        }
    }

    private func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: value)
    }
}

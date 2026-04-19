import Foundation

public enum ClaudeUsageBlockComputer {
    public static func computeBlocks(entries: [ClaudeUsageEntry], window: TimeInterval) -> [ClaudeUsageBlock] {
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

    public static func currentBlock(
        entries: [ClaudeUsageEntry],
        window: TimeInterval,
        now: Date = Date()
    ) -> ClaudeUsageBlock? {
        computeBlocks(entries: entries, window: window).last { $0.isActive(at: now) }
    }
}

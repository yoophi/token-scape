import CodexUsageCore
import SwiftUI

enum UsageViewMode: String, CaseIterable, Identifiable {
    case simple
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple:
            return "간단히"
        case .detailed:
            return "자세히"
        }
    }
}

enum AutoRefreshInterval: TimeInterval, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300

    var id: TimeInterval { rawValue }

    var title: String {
        switch self {
        case .oneMinute:
            return "1분"
        case .fiveMinutes:
            return "5분"
        }
    }
}

struct UsageProductDisplay {
    let title: String
    let systemImage: String
    let accent: Color
    let shortWindow: UsageWindowDisplay?
    let weeklyWindow: UsageWindowDisplay?
    let tokens: TokenBreakdownDisplay?
    let activityLabel: String?
    let planLabel: String?
    let sourcePath: String
    let loadedAt: Date
}

struct UsageWindowDisplay {
    let title: String
    let subtitle: String
    let remainingTimeText: String
    let remainingPercentText: String
    let supportingMetric: String
    let progressValue: Double
    let progressLabel: String
    let resetLabel: String
    let detailRows: [UsageDetailRow]
    let progressColor: Color
}

struct UsageDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct TokenBreakdownDisplay {
    let total: Int
    let input: Int
    let output: Int
    let cacheWrite: Int
    let cacheRead: Int
    let cachedInput: Int
    let reasoning: Int
    let recentTotal: Int?
}

enum UsageDisplayMapper {
    static func codex(_ snapshot: UsageSnapshot, now: Date) -> UsageProductDisplay {
        UsageProductDisplay(
            title: "Codex",
            systemImage: "terminal",
            accent: .green,
            shortWindow: codexWindow("5시간 창", "짧은 기간 사용량", limit: snapshot.primary, now: now),
            weeklyWindow: codexWindow("주간 창", "긴 기간 사용량", limit: snapshot.secondary, now: now),
            tokens: snapshot.totalTokenUsage.map { usage in
                TokenBreakdownDisplay(
                    total: usage.totalTokens,
                    input: usage.inputTokens,
                    output: usage.outputTokens,
                    cacheWrite: 0,
                    cacheRead: 0,
                    cachedInput: usage.cachedInputTokens,
                    reasoning: usage.reasoningOutputTokens,
                    recentTotal: snapshot.lastTokenUsage?.totalTokens
                )
            },
            activityLabel: snapshot.lastTokenUsage.map { "최근 응답 \(UsageFormatters.tokens($0.totalTokens)) tokens" },
            planLabel: snapshot.planType?.uppercased(),
            sourcePath: snapshot.sourcePath,
            loadedAt: snapshot.loadedAt
        )
    }

    static func claude(_ snapshot: ClaudeUsageSnapshot, now: Date) -> UsageProductDisplay {
        UsageProductDisplay(
            title: "Claude Code",
            systemImage: "sparkles",
            accent: .purple,
            shortWindow: claudeWindow("5시간 창", "세션 블록", block: snapshot.fiveHourBlock, window: 5 * 3600, now: now),
            weeklyWindow: claudeWindow("주간 창", "7일 블록", block: snapshot.weeklyBlock, window: 7 * 24 * 3600, now: now),
            tokens: claudeTokens(snapshot),
            activityLabel: "\(UsageFormatters.tokens(snapshot.entryCount))개 메시지",
            planLabel: nil,
            sourcePath: snapshot.sourcePath,
            loadedAt: snapshot.loadedAt
        )
    }

    private static func codexWindow(
        _ title: String,
        _ subtitle: String,
        limit: UsageSnapshot.Limit?,
        now: Date
    ) -> UsageWindowDisplay? {
        guard let limit else {
            return nil
        }

        let resetLabel = limit.resetsAt.map {
            "\(UsageFormatters.duration($0.timeIntervalSince(now))) 남음 · \(UsageFormatters.clock($0)) 리셋"
        } ?? "리셋 정보 없음"

        let windowLabel = limit.windowMinutes.map { minutes in
            minutes >= 1_440 ? "\(minutes / 1_440)일 창" : "\(minutes / 60)시간 창"
        } ?? "창 정보 없음"

        return UsageWindowDisplay(
            title: title,
            subtitle: subtitle,
            remainingTimeText: limit.resetsAt.map { UsageFormatters.duration($0.timeIntervalSince(now)) } ?? "--",
            remainingPercentText: "\(Int(limit.remainingPercent.rounded()))%",
            supportingMetric: "사용 \(UsageFormatters.percent(limit.usedPercent))%",
            progressValue: max(0, min(1, limit.usedPercent / 100)),
            progressLabel: "한도 사용률",
            resetLabel: resetLabel,
            detailRows: [
                UsageDetailRow(label: "창", value: windowLabel),
                UsageDetailRow(label: "사용률", value: "\(UsageFormatters.percent(limit.usedPercent))%"),
                UsageDetailRow(label: "남은 비율", value: "\(UsageFormatters.percent(limit.remainingPercent))%"),
                UsageDetailRow(label: "리셋", value: resetLabel)
            ],
            progressColor: remainingColor(limit.remainingPercent)
        )
    }

    private static func claudeWindow(
        _ title: String,
        _ subtitle: String,
        block: ClaudeUsageBlock?,
        window: TimeInterval,
        now: Date
    ) -> UsageWindowDisplay? {
        guard let block else {
            return UsageWindowDisplay(
                title: title,
                subtitle: subtitle,
                remainingTimeText: "비활성",
                remainingPercentText: "--",
                supportingMetric: "다음 메시지 대기",
                progressValue: 0,
                progressLabel: "시간 진행률",
                resetLabel: "다음 메시지를 보내면 새 \(UsageFormatters.window(window)) 블록 시작",
                detailRows: [
                    UsageDetailRow(label: "상태", value: "활성 블록 없음"),
                    UsageDetailRow(label: "창", value: UsageFormatters.window(window))
                ],
                progressColor: .gray
            )
        }

        let total = block.end.timeIntervalSince(block.start)
        let elapsed = max(0, min(total, now.timeIntervalSince(block.start)))
        let progress = total > 0 ? elapsed / total : 0
        let remaining = block.timeRemaining(from: now)
        let remainingPercent = total > 0 ? max(0, min(100, (remaining / total) * 100)) : 0
        let resetLabel = "\(UsageFormatters.duration(remaining)) 남음 · \(UsageFormatters.clock(block.end)) 리셋"

        return UsageWindowDisplay(
            title: title,
            subtitle: subtitle,
            remainingTimeText: UsageFormatters.duration(remaining),
            remainingPercentText: "\(Int(remainingPercent.rounded()))%",
            supportingMetric: "\(UsageFormatters.tokens(block.totalTokens)) tokens",
            progressValue: progress,
            progressLabel: "시간 진행률",
            resetLabel: resetLabel,
            detailRows: [
                UsageDetailRow(label: "시작", value: UsageFormatters.fullDate(block.start)),
                UsageDetailRow(label: "리셋", value: UsageFormatters.fullDate(block.end)),
                UsageDetailRow(label: "남은 시간", value: UsageFormatters.duration(remaining)),
                UsageDetailRow(label: "사용 토큰", value: UsageFormatters.tokens(block.totalTokens)),
                UsageDetailRow(label: "메시지 수", value: "\(block.messageCount)")
            ],
            progressColor: .purple
        )
    }

    private static func claudeTokens(_ snapshot: ClaudeUsageSnapshot) -> TokenBreakdownDisplay? {
        let blocks = [snapshot.fiveHourBlock, snapshot.weeklyBlock].compactMap { $0 }
        guard let block = blocks.max(by: { $0.totalTokens < $1.totalTokens }) else {
            return nil
        }

        return TokenBreakdownDisplay(
            total: block.totalTokens,
            input: block.inputTokens,
            output: block.outputTokens,
            cacheWrite: block.cacheCreationTokens,
            cacheRead: block.cacheReadTokens,
            cachedInput: 0,
            reasoning: 0,
            recentTotal: nil
        )
    }

    private static func remainingColor(_ remainingPercent: Double) -> Color {
        switch remainingPercent {
        case ..<10:
            return .red
        case ..<25:
            return .orange
        default:
            return .green
        }
    }
}

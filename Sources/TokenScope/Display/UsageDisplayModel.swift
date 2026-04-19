import TokenScopeCore
import SwiftUI

extension Color {
    static let tokenScopeCodex = Color(red: 16 / 255, green: 163 / 255, blue: 127 / 255)
    static let tokenScopeClaude = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
}

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

enum AutoRefreshOption: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMinute:
            return "1분"
        case .fiveMinutes:
            return "5분"
        case .off:
            return "안함"
        }
    }

    init(isEnabled: Bool, interval: AutoRefreshInterval) {
        guard isEnabled else {
            self = .off
            return
        }

        switch interval {
        case .oneMinute:
            self = .oneMinute
        case .fiveMinutes:
            self = .fiveMinutes
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
    let remainingPercentLabel: String
    let remainingPercentText: String
    let supportingMetric: String
    let progressValue: Double
    let progressLabel: String
    let resetLabel: String
    let timeRemainingPercent: Double?
    let usageRemainingLabel: String
    let usageRemainingPercent: Double?
    let detailRows: [UsageDetailRow]
    let progressColor: Color
}

struct UsageDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct TokenBreakdownDisplay {
    let title: String
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
            accent: .tokenScopeCodex,
            shortWindow: codexWindow("5시간 창", "짧은 기간 사용량", limit: snapshot.primary, now: now, usesClockDuration: true),
            weeklyWindow: codexWindow("주간 창", "긴 기간 사용량", limit: snapshot.secondary, now: now, usesClockDuration: false),
            tokens: snapshot.totalTokenUsage.map { usage in
                TokenBreakdownDisplay(
                    title: "토큰",
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
            accent: .tokenScopeClaude,
            shortWindow: claudeWindow(
                "5시간 창",
                fallbackSubtitle: "세션 블록",
                block: snapshot.fiveHourBlock,
                limit: snapshot.usageLimits?.fiveHour,
                limitSource: snapshot.usageLimits?.source,
                window: 5 * 3600,
                now: now,
                usesClockDuration: true
            ),
            weeklyWindow: claudeWindow(
                "주간 창",
                fallbackSubtitle: "7일 블록",
                block: snapshot.weeklyBlock,
                limit: snapshot.usageLimits?.sevenDay,
                limitSource: snapshot.usageLimits?.source,
                window: 7 * 24 * 3600,
                now: now,
                usesClockDuration: false
            ),
            tokens: claudeTokens(snapshot),
            activityLabel: "\(UsageFormatters.tokens(snapshot.entryCount))개 메시지",
            planLabel: snapshot.usageLimits.map { usageLimitsLabel($0) },
            sourcePath: snapshot.usageLimits?.sourcePath ?? snapshot.sourcePath,
            loadedAt: snapshot.loadedAt
        )
    }

    private static func codexWindow(
        _ title: String,
        _ subtitle: String,
        limit: UsageSnapshot.Limit?,
        now: Date,
        usesClockDuration: Bool
    ) -> UsageWindowDisplay? {
        guard let limit else {
            return nil
        }

        let remainingText = limit.resetsAt.map {
            formatRemaining($0.timeIntervalSince(now), usesClockDuration: usesClockDuration)
        } ?? "--"
        let resetLabel = limit.resetsAt.map {
            "\(formatRemaining($0.timeIntervalSince(now), usesClockDuration: usesClockDuration)) 남음 · \(UsageFormatters.clock($0)) 리셋"
        } ?? "리셋 정보 없음"

        let windowLabel = limit.windowMinutes.map { minutes in
            minutes >= 1_440 ? "\(minutes / 1_440)일 창" : "\(minutes / 60)시간 창"
        } ?? "창 정보 없음"
        let timeRemainingPercent = codexTimeRemainingPercent(limit: limit, now: now)

        return UsageWindowDisplay(
            title: title,
            subtitle: subtitle,
            remainingTimeText: remainingText,
            remainingPercentLabel: "남은 비율",
            remainingPercentText: "\(Int(limit.remainingPercent.rounded()))%",
            supportingMetric: "사용 \(UsageFormatters.percent(limit.usedPercent))%",
            progressValue: max(0, min(1, limit.usedPercent / 100)),
            progressLabel: "한도 사용률",
            resetLabel: resetLabel,
            timeRemainingPercent: timeRemainingPercent,
            usageRemainingLabel: "남은 사용량",
            usageRemainingPercent: limit.remainingPercent,
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
        fallbackSubtitle: String,
        block: ClaudeUsageBlock?,
        limit: ClaudeUsageLimits.Window?,
        limitSource: ClaudeUsageLimits.Source?,
        window: TimeInterval,
        now: Date,
        usesClockDuration: Bool
    ) -> UsageWindowDisplay? {
        if let limit {
            return claudeLimitWindow(
                title,
                limit: limit,
                source: limitSource ?? .localEstimate,
                window: window,
                now: now,
                usesClockDuration: usesClockDuration
            )
        }

        guard let block else {
            return UsageWindowDisplay(
                title: title,
                subtitle: fallbackSubtitle,
                remainingTimeText: "비활성",
                remainingPercentLabel: "블록 잔여",
                remainingPercentText: "--",
                supportingMetric: "다음 메시지 대기",
                progressValue: 0,
                progressLabel: "시간 진행률",
                resetLabel: "다음 메시지를 보내면 새 \(UsageFormatters.window(window)) 블록 시작",
                timeRemainingPercent: nil,
                usageRemainingLabel: "한도 정보",
                usageRemainingPercent: nil,
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
        let remainingText = formatRemaining(remaining, usesClockDuration: usesClockDuration)
        let resetLabel = "\(remainingText) 남음 · \(UsageFormatters.clock(block.end)) 리셋"

        return UsageWindowDisplay(
            title: title,
            subtitle: fallbackSubtitle,
            remainingTimeText: remainingText,
            remainingPercentLabel: "블록 잔여",
            remainingPercentText: "\(Int(remainingPercent.rounded()))%",
            supportingMetric: "\(UsageFormatters.tokens(block.totalTokens)) tokens",
            progressValue: progress,
            progressLabel: "시간 진행률",
            resetLabel: resetLabel,
            timeRemainingPercent: remainingPercent,
            usageRemainingLabel: "한도 정보",
            usageRemainingPercent: nil,
            detailRows: [
                UsageDetailRow(label: "시작", value: UsageFormatters.fullDate(block.start)),
                UsageDetailRow(label: "리셋", value: UsageFormatters.fullDate(block.end)),
                UsageDetailRow(label: "남은 시간", value: remainingText),
                UsageDetailRow(label: "블록 잔여", value: "\(UsageFormatters.percent(remainingPercent))%"),
                UsageDetailRow(label: "사용 토큰", value: UsageFormatters.tokens(block.totalTokens)),
                UsageDetailRow(label: "메시지 수", value: "\(block.messageCount)")
            ],
            progressColor: .tokenScopeClaude
        )
    }

    private static func claudeLimitWindow(
        _ title: String,
        limit: ClaudeUsageLimits.Window,
        source: ClaudeUsageLimits.Source,
        window: TimeInterval,
        now: Date,
        usesClockDuration: Bool
    ) -> UsageWindowDisplay {
        let remainingText = limit.resetsAt.map {
            formatRemaining($0.timeIntervalSince(now), usesClockDuration: usesClockDuration)
        } ?? "--"
        let resetLabel = limit.resetsAt.map {
            "\(formatRemaining($0.timeIntervalSince(now), usesClockDuration: usesClockDuration)) 남음 · \(UsageFormatters.clock($0)) 리셋"
        } ?? "리셋 정보 없음"
        let timeRemainingPercent = limit.resetsAt.map {
            remainingTimePercent(resetsAt: $0, window: window, now: now)
        }

        let sourceText = sourceDescription(source)
        return UsageWindowDisplay(
            title: title,
            subtitle: sourceText,
            remainingTimeText: remainingText,
            remainingPercentLabel: "남은 비율",
            remainingPercentText: "\(Int(limit.remainingPercent.rounded()))%",
            supportingMetric: "사용 \(UsageFormatters.percent(limit.usedPercent))%",
            progressValue: max(0, min(1, limit.usedPercent / 100)),
            progressLabel: "한도 사용률",
            resetLabel: resetLabel,
            timeRemainingPercent: timeRemainingPercent,
            usageRemainingLabel: "남은 사용량",
            usageRemainingPercent: limit.remainingPercent,
            detailRows: [
                UsageDetailRow(label: "출처", value: sourceText),
                UsageDetailRow(label: "사용률", value: "\(UsageFormatters.percent(limit.usedPercent))%"),
                UsageDetailRow(label: "남은 비율", value: "\(UsageFormatters.percent(limit.remainingPercent))%"),
                UsageDetailRow(label: "시간 잔여", value: timeRemainingPercent.map { "\(UsageFormatters.percent($0))%" } ?? "--"),
                UsageDetailRow(label: "리셋", value: resetLabel)
            ],
            progressColor: remainingColor(limit.remainingPercent, healthyColor: .tokenScopeClaude)
        )
    }

    private static func codexTimeRemainingPercent(limit: UsageSnapshot.Limit, now: Date) -> Double? {
        guard let resetsAt = limit.resetsAt,
              let windowMinutes = limit.windowMinutes,
              windowMinutes > 0
        else {
            return nil
        }

        let total = TimeInterval(windowMinutes * 60)
        let remaining = max(0, min(total, resetsAt.timeIntervalSince(now)))
        return (remaining / total) * 100
    }

    private static func remainingTimePercent(resetsAt: Date, window: TimeInterval, now: Date) -> Double {
        guard window > 0 else {
            return 0
        }

        let remaining = max(0, min(window, resetsAt.timeIntervalSince(now)))
        return (remaining / window) * 100
    }

    private static func claudeTokens(_ snapshot: ClaudeUsageSnapshot) -> TokenBreakdownDisplay? {
        let candidates = [
            (label: "5시간 블록 토큰", block: snapshot.fiveHourBlock),
            (label: "7일 블록 토큰", block: snapshot.weeklyBlock)
        ].compactMap { item in
            item.block.map { (label: item.label, block: $0) }
        }
        guard let selected = candidates.max(by: { $0.block.totalTokens < $1.block.totalTokens }) else {
            return nil
        }
        let block = selected.block

        return TokenBreakdownDisplay(
            title: selected.label,
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

    private static func sourceLabel(_ source: ClaudeUsageLimits.Source) -> String {
        switch source {
        case .oauthAPI:
            return "OAUTH"
        case .ccusageCache:
            return "CCUSAGE"
        case .statuslineCache:
            return "STATUSLINE"
        case .localEstimate:
            return "로컬 추정"
        }
    }

    private static func sourceDescription(_ source: ClaudeUsageLimits.Source) -> String {
        switch source {
        case .oauthAPI:
            return "Anthropic OAuth API"
        case .ccusageCache:
            return "ccusage 캐시"
        case .statuslineCache:
            return "statusline 캐시"
        case .localEstimate:
            return "로컬 추정"
        }
    }

    private static func usageLimitsLabel(_ limits: ClaudeUsageLimits) -> String {
        guard limits.source == .oauthAPI, let planName = limits.planName else {
            return sourceLabel(limits.source)
        }

        return "\(sourceLabel(limits.source)) · \(planName)"
    }

    private static func remainingColor(_ remainingPercent: Double, healthyColor: Color = .tokenScopeCodex) -> Color {
        switch remainingPercent {
        case ..<10:
            return .red
        case ..<25:
            return .orange
        default:
            return healthyColor
        }
    }

    private static func formatRemaining(_ seconds: TimeInterval, usesClockDuration: Bool) -> String {
        if usesClockDuration {
            return UsageFormatters.hoursMinutesSeconds(seconds)
        }

        return UsageFormatters.duration(seconds)
    }
}

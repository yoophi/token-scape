import SwiftUI

struct UsageSummaryCard: View {
    let display: UsageProductDisplay
    let mode: UsageViewMode

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header

            if let shortWindow = display.shortWindow {
                UnifiedUsageWindowCard(window: shortWindow, mode: mode)
            }

            if let weeklyWindow = display.weeklyWindow {
                UnifiedUsageWindowCard(window: weeklyWindow, mode: mode)
            }

            if mode == .simple {
                compactTokenSummary
            } else {
                detailContent
            }
        }
    }

    private var sectionSpacing: CGFloat {
        mode == .simple ? 10 : 14
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(display.title, systemImage: display.systemImage)
                .font(.title3.bold())
                .foregroundStyle(display.accent)
            Spacer()
            if let planLabel = display.planLabel {
                Text(planLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(display.accent.opacity(0.14)))
                    .foregroundStyle(display.accent)
            }
        }
    }

    @ViewBuilder
    private var compactTokenSummary: some View {
        if let tokens = display.tokens {
            HStack(spacing: 10) {
                Label("토큰", systemImage: "number")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(UsageFormatters.tokens(tokens.total))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Spacer()
                if let activityLabel = display.activityLabel {
                    Text(activityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .cardStyle(padding: 10)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let tokens = display.tokens {
            UnifiedTokenBreakdownCard(tokens: tokens)
        }

        MetadataCard(
            title: display.activityLabel ?? "활동 정보 없음",
            systemImage: "chart.bar",
            sourcePath: display.sourcePath,
            loadedAt: display.loadedAt
        )
    }
}

struct UnifiedUsageWindowCard: View {
    let window: UsageWindowDisplay
    let mode: UsageViewMode

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(window.title)
                        .font(.headline)
                    Text(window.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                remainingMetrics
            }

            ProgressView(value: window.progressValue)
                .tint(window.progressColor)

            HStack {
                Text(window.progressLabel)
                Spacer()
                Text(window.supportingMetric)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(window.resetLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if mode == .detailed {
                Divider()
                UsageWindowPieCharts(window: window)
                Divider()
                detailRows
            }
        }
        .cardStyle(padding: cardPadding)
    }

    private var cardPadding: CGFloat {
        mode == .simple ? 10 : 16
    }

    private var verticalSpacing: CGFloat {
        mode == .simple ? 8 : 12
    }

    private var remainingMetrics: some View {
        VStack(alignment: .trailing, spacing: 6) {
            metricRow(label: "남은 시간", value: window.remainingTimeText, prominent: true)
            metricRow(label: "남은 비율", value: window.remainingPercentText, prominent: false)
        }
        .frame(width: mode == .simple ? 128 : 150, alignment: .trailing)
    }

    private func metricRow(label: String, value: String, prominent: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: metricFontSize(prominent: prominent), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func metricFontSize(prominent: Bool) -> CGFloat {
        if mode == .simple {
            return prominent ? 18 : 14
        }
        return prominent ? 22 : 16
    }

    private var detailRows: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(window.detailRows) { row in
                GridRow {
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(row.value)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }
}

private struct UsageWindowPieCharts: View {
    let window: UsageWindowDisplay

    var body: some View {
        HStack(spacing: 16) {
            UsagePieChart(
                title: "남은 시간",
                percent: window.timeRemainingPercent,
                color: window.progressColor
            )
            UsagePieChart(
                title: "남은 사용량",
                percent: window.usageRemainingPercent,
                color: window.progressColor
            )
        }
    }
}

private struct UsagePieChart: View {
    let title: String
    let percent: Double?
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))

                if let normalizedPercent {
                    PieSlice(progress: normalizedPercent)
                        .fill(color)
                }

                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(percentText)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalizedPercent: Double? {
        guard let percent else {
            return nil
        }

        return max(0, min(1, percent / 100))
    }

    private var percentText: String {
        guard let percent else {
            return "--"
        }

        return "\(Int(percent.rounded()))%"
    }
}

private struct PieSlice: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + 360 * progress)

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct UnifiedTokenBreakdownCard: View {
    let tokens: TokenBreakdownDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("토큰")
                    .font(.headline)
                Spacer()
                Text(UsageFormatters.tokens(tokens.total))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                TokenChip(label: "Input", value: tokens.input, color: .blue)
                TokenChip(label: "Output", value: tokens.output, color: .orange)
            }

            HStack(spacing: 10) {
                TokenChip(label: "Cache W", value: tokens.cacheWrite, color: .pink)
                TokenChip(label: "Cache R", value: tokens.cacheRead + tokens.cachedInput, color: .teal)
                TokenChip(label: "Reasoning", value: tokens.reasoning, color: .purple)
            }

            if let recentTotal = tokens.recentTotal {
                Text("최근 응답 \(UsageFormatters.tokens(recentTotal)) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

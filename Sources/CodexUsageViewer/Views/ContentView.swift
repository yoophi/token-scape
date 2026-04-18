import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            ScrollView {
                usageColumns
                    .padding(.trailing, 2)
            }
            Divider()
            footer
        }
        .padding(24)
        .frame(width: contentWidth)
        .frame(minHeight: contentMinimumHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var contentWidth: CGFloat {
        store.viewMode == .simple ? 1_060 : 1_180
    }

    private var contentMinimumHeight: CGFloat {
        store.viewMode == .simple ? 550 : 760
    }

    private var usageColumns: some View {
        HStack(alignment: .top, spacing: 18) {
            productColumn(
                title: "Claude Code",
                errorTitle: "Claude Code 사용량 정보를 찾지 못했습니다.",
                errorMessage: store.claudeError,
                display: store.claudeSnapshot.map { UsageDisplayMapper.claude($0, now: store.now) }
            )

            Divider()
                .frame(minHeight: store.viewMode == .simple ? 360 : 640)

            productColumn(
                title: "Codex",
                errorTitle: "Codex 사용량 정보를 찾지 못했습니다.",
                errorMessage: store.codexError,
                display: store.codexSnapshot.map { UsageDisplayMapper.codex($0, now: store.now) }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text("AI Code 사용량")
                            .font(.system(size: 24, weight: .bold))
                        if store.isAlwaysOnTop {
                            Label("항상 위", systemImage: "pin.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("왼쪽 Claude Code · 오른쪽 Codex")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.refresh()
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)
                .help("새로고침")
            }

            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("보기")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("보기", selection: $store.viewMode) {
                    ForEach(UsageViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }

            Toggle(isOn: $store.isAutoRefreshEnabled) {
                Label("자동 새로고침", systemImage: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.checkbox)

            Picker("간격", selection: $store.autoRefreshInterval) {
                ForEach(AutoRefreshInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .disabled(!store.isAutoRefreshEnabled)

            Toggle(isOn: $store.isAlwaysOnTop) {
                Label("항상 위", systemImage: store.isAlwaysOnTop ? "pin.fill" : "pin")
            }
            .toggleStyle(.checkbox)

            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Text("마지막 업데이트: \(store.lastRefresh == .distantPast ? "-" : UsageFormatters.clock(store.lastRefresh))")
            Spacer()
            Text(refreshStatus)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var refreshStatus: String {
        guard store.isAutoRefreshEnabled else {
            return "자동 새로고침 꺼짐"
        }

        guard let nextAutoRefreshAt = store.nextAutoRefreshAt else {
            return "자동 새로고침 \(store.autoRefreshInterval.title) · 다음 새로고침 계산 중"
        }

        let remainingSeconds = max(0, Int(ceil(nextAutoRefreshAt.timeIntervalSince(store.now))))
        return "자동 새로고침 \(store.autoRefreshInterval.title) · \(remainingSeconds)초 후 새로고침"
    }

    private func productColumn(
        title: String,
        errorTitle: String,
        errorMessage: String?,
        display: UsageProductDisplay?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let display {
                UsageSummaryCard(display: display, mode: store.viewMode)
            } else {
                Text(title)
                    .font(.title3.bold())
                ErrorCard(
                    title: errorTitle,
                    message: errorMessage ?? "\(title)를 한 번 실행한 뒤 다시 시도하세요."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

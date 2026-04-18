import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: bodySpacing) {
            header
            ScrollView {
                usageColumns
                    .padding(.trailing, 2)
            }
            Divider()
            footer
        }
        .padding(contentPadding)
        .frame(
            minWidth: contentMinimumWidth,
            maxWidth: .infinity,
            minHeight: contentMinimumHeight,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var contentMinimumWidth: CGFloat {
        store.viewMode == .simple ? 900 : 1_080
    }

    private var contentMinimumHeight: CGFloat {
        store.viewMode == .simple ? 500 : 760
    }

    private var contentPadding: CGFloat {
        store.viewMode == .simple ? 16 : 24
    }

    private var bodySpacing: CGFloat {
        store.viewMode == .simple ? 12 : 18
    }

    private var usageColumns: some View {
        HStack(alignment: .top, spacing: store.viewMode == .simple ? 12 : 18) {
            productColumn(
                title: "Claude Code",
                errorTitle: "Claude Code 사용량 정보를 찾지 못했습니다.",
                errorMessage: store.claudeError,
                display: store.claudeSnapshot.map { UsageDisplayMapper.claude($0, now: store.now) }
            )

            Divider()
                .frame(minHeight: store.viewMode == .simple ? 300 : 640)

            productColumn(
                title: "Codex",
                errorTitle: "Codex 사용량 정보를 찾지 못했습니다.",
                errorMessage: store.codexError,
                display: store.codexSnapshot.map { UsageDisplayMapper.codex($0, now: store.now) }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                Text("AI Code 사용량")
                    .font(.system(size: store.viewMode == .simple ? 22 : 24, weight: .bold))
                    .lineLimit(1)

                if store.isAlwaysOnTop {
                    Label("항상 위", systemImage: "pin.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                        .fixedSize()
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            headerControls
        }
    }

    private var headerControls: some View {
        HStack(spacing: store.viewMode == .simple ? 8 : 10) {
            Picker("보기", selection: $store.viewMode) {
                ForEach(UsageViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: store.viewMode == .simple ? 136 : 156)
            .help("보기 방식")

            Label("자동 새로고침", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize()

            Picker("자동 새로고침", selection: autoRefreshOption) {
                ForEach(AutoRefreshOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)

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

            Button {
                store.isAlwaysOnTop.toggle()
            } label: {
                Image(systemName: store.isAlwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(store.isAlwaysOnTop ? .orange : .primary)
            }
            .buttonStyle(.bordered)
            .help(store.isAlwaysOnTop ? "항상 위 끄기" : "항상 위 켜기")
        }
        .layoutPriority(2)
    }

    private var autoRefreshOption: Binding<AutoRefreshOption> {
        Binding(
            get: { store.autoRefreshOption },
            set: { store.autoRefreshOption = $0 }
        )
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
        VStack(alignment: .leading, spacing: store.viewMode == .simple ? 10 : 14) {
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

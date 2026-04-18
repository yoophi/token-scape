import SwiftUI

struct MetadataCard: View {
    let title: String
    let systemImage: String
    let sourcePath: String
    let loadedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("갱신: \(UsageFormatters.clock(loadedAt))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Text(sourcePath)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .cardStyle()
    }
}

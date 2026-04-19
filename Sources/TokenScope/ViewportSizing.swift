import Foundation

enum ViewportSizing {
    struct Metrics {
        let defaultSize: CGSize
        let minimumSize: CGSize
        let contentPadding: CGFloat
        let bodySpacing: CGFloat
        let columnSpacing: CGFloat
        let dividerMinimumHeight: CGFloat
    }

    static func metrics(for viewMode: UsageViewMode) -> Metrics {
        switch viewMode {
        case .simple:
            return Metrics(
                defaultSize: CGSize(width: 960, height: 560),
                minimumSize: CGSize(width: 900, height: 500),
                contentPadding: 16,
                bodySpacing: 12,
                columnSpacing: 12,
                dividerMinimumHeight: 300
            )
        case .detailed:
            return Metrics(
                defaultSize: CGSize(width: 1_180, height: 820),
                minimumSize: CGSize(width: 1_080, height: 680),
                contentPadding: 24,
                bodySpacing: 18,
                columnSpacing: 18,
                dividerMinimumHeight: 640
            )
        }
    }
}

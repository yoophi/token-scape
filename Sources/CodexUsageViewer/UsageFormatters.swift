import Foundation

enum UsageFormatters {
    static func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    static func tokens(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return String(format: "%dd %02dh %02dm", days, remainingHours, minutes)
        }

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    static func window(_ window: TimeInterval) -> String {
        if window >= 24 * 3600 {
            return "\(Int(window / (24 * 3600)))일"
        }
        return "\(Int(window / 3600))시간"
    }
}

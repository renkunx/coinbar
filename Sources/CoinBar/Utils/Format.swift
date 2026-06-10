import Foundation

enum Format {
    static func price(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        switch value {
        case 0:
            return "-"
        case 1000...:
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        case 1..<1000:
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        case 0.01..<1:
            formatter.minimumFractionDigits = 4
            formatter.maximumFractionDigits = 4
        default:
            formatter.minimumFractionDigits = 6
            formatter.maximumFractionDigits = 6
        }

        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func changePct(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    static func compactPrice(_ value: Double) -> String {
        switch value {
        case 1_000_000_000...:
            String(format: "%.2fB", value / 1_000_000_000)
        case 1_000_000...:
            String(format: "%.2fM", value / 1_000_000)
        case 1_000...:
            String(format: "%.1fK", value / 1_000)
        default:
            price(value)
        }
    }

    static func volume(_ value: Double) -> String {
        switch value {
        case 1_000_000_000...:
            String(format: "%.2fB", value / 1_000_000_000)
        case 1_000_000...:
            String(format: "%.2fM", value / 1_000_000)
        case 1_000...:
            String(format: "%.1fK", value / 1_000)
        default:
            String(format: "%.0f", value)
        }
    }
}

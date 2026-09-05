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
        case 10..<1000:
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        case 1..<10:
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 3
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

    /// 整数展示阈值百分比：去掉尾部多余零（5 -> "5"，5.5 -> "5.5"）
    static func trimmedDecimal(_ value: Double) -> String {
        let s = String(format: "%.2f", value)
        guard let dot = s.firstIndex(of: ".") else { return s }
        var intPart = s[..<dot]
        var frac = s[s.index(after: dot)...]
        while frac.last == "0" { frac = frac.dropLast() }
        if frac.isEmpty {
            // 去掉负零整数部分的负号（-0 -> 0）
            if intPart == "-0" { intPart = "0" }
            return String(intPart)
        }
        return "\(intPart).\(frac)"
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

    static func menuBarPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        switch value {
        case 0:
            return "-"
        case 1000...:
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        case 10..<1000:
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        case 1..<10:
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 3
        case 0.01..<1:
            formatter.minimumFractionDigits = 4
            formatter.maximumFractionDigits = 4
        default:
            formatter.minimumFractionDigits = 6
            formatter.maximumFractionDigits = 6
        }

        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

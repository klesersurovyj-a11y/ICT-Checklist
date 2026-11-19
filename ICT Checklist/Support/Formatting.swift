//
//  Formatting.swift
//  ICT Checklist
//

import Foundation

enum Fmt {
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 5
        return formatter
    }()

    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func price(_ value: Double?) -> String {
        guard let value else { return "—" }
        return priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.5f", value)
    }

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        let text = moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "$" + text
    }

    /// Деньги с разделителем разрядов и знаком валюты после числа: «12 480 $».
    static func groupedMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = abs(value) >= 100 ? 0 : 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return text + " $"
    }

    static func groupedMoneySigned(_ value: Double) -> String {
        guard abs(value) >= 0.005 else { return groupedMoney(0) }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + groupedMoney(abs(value))
    }

    /// Процент со знаком: «+4.2%», «−3.2%».
    static func signedPercent(_ value: Double) -> String {
        guard abs(value) >= 0.005 else { return "0.0%" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f%%", abs(value))
    }

    static func r(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0R" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f", abs(value)) + "R"
    }

    static func rr(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func signed(_ value: Double, digits: Int = 1) -> String {
        let threshold = digits == 1 ? 0.05 : 0.005
        let magnitude = abs(value)
        let text = String(format: "%.\(digits)f", magnitude)
        guard magnitude >= threshold else { return String(format: "%.\(digits)f", 0.0) }
        return (value > 0 ? "+" : "\u{2212}") + text
    }

    static func dealWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "сделок" }
        if mod10 == 1 { return "сделка" }
        if mod10 >= 2 && mod10 <= 4 { return "сделки" }
        return "сделок"
    }

    static func deals(_ count: Int) -> String {
        "\(count) \(dealWord(count))"
    }

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let text = dayFormatter.string(from: date)
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    static func shortDay(_ date: Date) -> String {
        let text = shortDayFormatter.string(from: date)
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func clock(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func month(_ date: Date) -> String {
        let text = monthFormatter.string(from: date)
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    static func weekday(_ date: Date) -> String {
        let text = weekdayFormatter.string(from: date)
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static func monthYear(_ date: Date) -> String {
        let text = monthFormatter.string(from: date) + " " + yearSuffix(date)
        return text
    }

    private static func yearSuffix(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    static func tradingDays(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        let word: String
        if mod100 >= 11 && mod100 <= 14 {
            word = "торговых дней"
        } else if mod10 == 1 {
            word = "торговый день"
        } else if mod10 >= 2 && mod10 <= 4 {
            word = "торговых дня"
        } else {
            word = "торговых дней"
        }
        return "\(count) \(word)"
    }

    static func distancePercent(_ price: Double, from reference: Double) -> String {
        guard reference != 0 else { return "" }
        let percent = abs(price - reference) / reference * 100
        return String(format: "%.2f%%", percent)
    }
}

//
//  ReminderService.swift
//  ICT Checklist
//

import Foundation
import UserNotifications

enum ReminderService {
    private static let startIdentifier = "reminder.cycle.start"
    private static let endIdentifier = "reminder.cycle.end"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleStart(hour: Int, minute: Int) {
        schedule(
            identifier: startIdentifier,
            hour: hour,
            minute: minute,
            title: "Старт цикла",
            body: "\(Fmt.clock(hour: hour, minute: minute)) — запустите торговый цикл и пройдите чек-лист."
        )
    }

    static func scheduleEnd(hour: Int, minute: Int) {
        schedule(
            identifier: endIdentifier,
            hour: hour,
            minute: minute,
            title: "Закрытие терминала",
            body: "\(Fmt.clock(hour: hour, minute: minute)) — закройте терминал и переведите открытую позицию в BE."
        )
    }

    static func cancelStart() {
        cancel(identifier: startIdentifier)
    }

    static func cancelEnd() {
        cancel(identifier: endIdentifier)
    }

    /// Сообщение о том, что позиция закрыта автоматически по рынку.
    static func notifyClosed(symbol: String, result: TradeResult, r: Double, price: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Позиция закрыта · \(symbol)"
        content.body = "\(result.rawValue) по \(Fmt.price(price)). Результат: \(Fmt.r(r))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "trade.closed.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Сообщение о том, что цель месяца достигнута.
    static func notifyGoal(monthR: Double, target: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Цель месяца достигнута"
        content.body = "\(Fmt.r(monthR)) из \(goalTargetText(target))"
        content.sound = .default
        content.userInfo = ["openGoal": true]

        let request = UNNotificationRequest(
            identifier: "goal.month.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func goalTargetText(_ value: Double) -> String {
        let rounded = value.rounded()
        let text = abs(value - rounded) < 0.05
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", value)
        return text + "R"
    }

    /// Сообщение о том, что дневной лимит исчерпан.
    static func notifyDailyLimit(tradesCount: Int, maxTrades: Int, dayR: Double, maxLossR: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Лимит дня · новых входов нет"
        content.body = "Сделок \(tradesCount)/\(maxTrades) · итог дня \(Fmt.r(dayR)) · лимит \(Fmt.r(-maxLossR))"
        content.sound = .default
        content.userInfo = ["openToday": true]

        let request = UNNotificationRequest(
            identifier: "limit.day.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static let journalPrefix = "reminder.journal."

    private static let weekPlanIdentifier = "reminder.weekplan"

    /// Одно напоминание про план новой недели на ближайшее воскресенье.
    static func scheduleWeekPlan(on date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weekPlanIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "План новой недели"
        content.body = "Заполните тему и сценарии следующей недели — так проще держать план."
        content.sound = .default
        content.userInfo = ["openWeek": true]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: weekPlanIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    static func cancelWeekPlan() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weekPlanIdentifier])
    }

    /// Планирует напоминания «Заполните дневник» через 15 минут после
    /// закрытия терминала на ближайшие дни.
    static func scheduleJournal(hour: Int, minute: Int, skipToday: Bool) {
        let center = UNUserNotificationCenter.current()
        cancelJournal()

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let total = hour * 60 + minute + 15
        let fireHour = (total / 60) % 24
        let fireMinute = total % 60

        var planned: [(String, DateComponents)] = []

        for offset in 0...8 {
            if offset == 0 && skipToday { continue }
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = fireHour
            components.minute = fireMinute

            guard let fireDate = calendar.date(from: components), fireDate > .now else { continue }

            planned.append((journalPrefix + journalDayFormatter.string(from: day), components))
            if planned.count == 7 { break }
        }

        for (identifier, components) in planned {
            let content = UNMutableNotificationContent()
            content.title = "Заполните дневник"
            content.body = "Запишите, как прошёл торговый день, пока помните детали."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelJournal() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        var identifiers: [String] = []

        for offset in 0...8 {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                identifiers.append(journalPrefix + journalDayFormatter.string(from: day))
            }
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static let journalDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func schedule(
        identifier: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private static func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

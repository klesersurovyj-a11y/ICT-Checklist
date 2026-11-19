//
//  TradeReviewReminder.swift
//  ICT Checklist
//
//  Локальное напоминание заполнить разбор сделки через час после закрытия.
//

import Foundation
import SwiftData
import UserNotifications

enum TradeReviewReminder {
    private static let prefix = "review-reminder-"

    static func schedule(for trade: Trade, context: ModelContext) {
        guard isEnabled(context) else {
            cancel(for: trade)
            return
        }

        guard trade.result != .open, let closedAt = trade.closedAt else { return }

        if let review = trade.review, review.isFilled {
            cancel(for: trade)
            return
        }

        let fireDate = closedAt.addingTimeInterval(3600)
        guard fireDate > .now else {
            cancel(for: trade)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Разбор сделки"
        content.body = "\(trade.symbol) · \(Fmt.r(trade.actualR)) — заполните разбор, пока помните вход."
        content.sound = .default

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: trade),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for trade: Trade) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: trade)])
    }

    /// Пересобирает напоминания: снимает те, где разбор уже заполнен,
    /// и ставит недостающие для недавно закрытых сделок.
    static func refresh(context: ModelContext) {
        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let recent = trades.filter { trade in
            guard trade.result != .open, let closedAt = trade.closedAt else { return false }
            return closedAt > Date().addingTimeInterval(-2 * 24 * 3600)
        }

        guard isEnabled(context) else {
            removeAll(recent)
            return
        }

        for trade in recent {
            schedule(for: trade, context: context)
        }
    }

    private static func removeAll(_ trades: [Trade]) {
        let identifiers = trades.map(identifier(for:))
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func isEnabled(_ context: ModelContext) -> Bool {
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
        return settings?.reviewReminderEnabled ?? false
    }

    private static func identifier(for trade: Trade) -> String {
        prefix + String(describing: trade.persistentModelID)
    }
}

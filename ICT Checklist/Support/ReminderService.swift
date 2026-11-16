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

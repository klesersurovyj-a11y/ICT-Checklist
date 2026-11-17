//
//  NotificationRouter.swift
//  ICT Checklist
//

import Foundation
import UserNotifications

/// Принимает нажатие на уведомление и просит приложение открыть нужный экран.
@MainActor
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Растёт при каждом нажатии на уведомление о цели.
    @Published private(set) var goalRequestTick = 0
    /// Растёт при каждом нажатии на уведомление о дневном лимите.
    @Published private(set) var todayRequestTick = 0
    /// Растёт при каждом нажатии на уведомление о плане недели.
    @Published private(set) var weekRequestTick = 0

    private var pendingGoalRequest = false
    private var pendingTodayRequest = false
    private var pendingWeekRequest = false

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Забирает ожидающий запрос: true — нужно открыть экран «Цель».
    func consumeGoalRequest() -> Bool {
        guard pendingGoalRequest else { return false }
        pendingGoalRequest = false
        return true
    }

    /// Забирает ожидающий запрос: true — нужно открыть вкладку «Сегодня».
    func consumeTodayRequest() -> Bool {
        guard pendingTodayRequest else { return false }
        pendingTodayRequest = false
        return true
    }

    /// Забирает ожидающий запрос: true — нужно открыть «Неделю».
    func consumeWeekRequest() -> Bool {
        guard pendingWeekRequest else { return false }
        pendingWeekRequest = false
        return true
    }

    private func requestGoal() {
        pendingGoalRequest = true
        goalRequestTick += 1
    }

    private func requestToday() {
        pendingTodayRequest = true
        todayRequestTick += 1
    }

    private func requestWeek() {
        pendingWeekRequest = true
        weekRequestTick += 1
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo

        if info["openGoal"] != nil {
            await requestGoal()
            return
        }

        if info["openToday"] != nil {
            await requestToday()
            return
        }

        if info["openWeek"] != nil {
            await requestWeek()
        }
    }
}

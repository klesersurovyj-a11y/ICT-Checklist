//
//  CycleActivity.swift
//  ICT Checklist
//
//  Live Activity цикла дня: время до конца, сделки и R до дневного лимита,
//  статус открытой сделки и расстояние до TP/SL в R.
//
//  Тип CycleActivityAttributes повторён в расширении виджета: ActivityKit
//  сопоставляет активность по имени типа, поэтому оба объявления совпадают.
//

import Foundation
import SwiftData
import ActivityKit
import WidgetKit

struct CycleActivityAttributes: ActivityAttributes {
    var cycleStart: Date

    struct ContentState: Codable, Hashable {
        var cycleEnd: Date
        var tradesToday: Int
        var maxTrades: Int
        var rToday: Double
        var maxLossR: Double
        var limitsEnabled: Bool

        var openSymbol: String?
        var openDirection: String?
        var openIsBE: Bool
        var openPrice: Double?
        var toTargetR: Double?
        var toStopR: Double?
    }
}

/// Всё, что нужно показать про текущий цикл, посчитанное из базы.
@MainActor
struct CycleLiveSnapshot {
    var cycleStart: Date
    var cycleEnd: Date
    var tradesToday: Int
    var maxTrades: Int
    var rToday: Double
    var maxLossR: Double
    var limitsEnabled: Bool

    var openSymbol: String?
    var openDirection: String?
    var openIsBE: Bool
    var openPrice: Double?
    var toTargetR: Double?
    var toStopR: Double?

    var state: CycleActivityAttributes.ContentState {
        CycleActivityAttributes.ContentState(
            cycleEnd: cycleEnd,
            tradesToday: tradesToday,
            maxTrades: maxTrades,
            rToday: rToday,
            maxLossR: maxLossR,
            limitsEnabled: limitsEnabled,
            openSymbol: openSymbol,
            openDirection: openDirection,
            openIsBE: openIsBE,
            openPrice: openPrice,
            toTargetR: toTargetR,
            toStopR: toStopR
        )
    }

    /// Возвращает данные цикла, только пока окно цикла идёт и в базе есть
    /// за что зацепиться: цикл дня, сделки сегодня или открытая сделка.
    static func build(context: ModelContext) -> CycleLiveSnapshot? {
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let startHour = settings?.cycleStartHour ?? 19
        let startMinute = settings?.cycleStartMinute ?? 0
        let endHour = settings?.cycleEndHour ?? 22
        let endMinute = settings?.cycleEndMinute ?? 0

        guard
            let start = calendar.date(
                bySettingHour: startHour,
                minute: startMinute,
                second: 0,
                of: today
            ),
            var end = calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: today
            )
        else { return nil }

        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        guard now >= start, now < end else { return nil }

        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let cycles = (try? context.fetch(FetchDescriptor<TradingCycle>())) ?? []

        let hasCycleToday = cycles.contains { calendar.isDate($0.day, inSameDayAs: today) }
        let todayTrades = trades.filter { calendar.isDate($0.tradingDay, inSameDayAs: today) }
        let openTrade = trades
            .filter { $0.result == .open }
            .sorted { $0.entryDate > $1.entryDate }
            .first

        guard hasCycleToday || !todayTrades.isEmpty || openTrade != nil else { return nil }

        let rToday = todayTrades
            .filter { $0.result != .open }
            .reduce(0) { $0 + $1.actualR }

        var snapshot = CycleLiveSnapshot(
            cycleStart: start,
            cycleEnd: end,
            tradesToday: todayTrades.count,
            maxTrades: max(settings?.maxTradesPerDay ?? 2, 1),
            rToday: rToday,
            maxLossR: max(settings?.maxDailyLossR ?? 2, 0.1),
            limitsEnabled: settings?.dailyLimitsEnabled ?? false,
            openSymbol: nil,
            openDirection: nil,
            openIsBE: false,
            openPrice: nil,
            toTargetR: nil,
            toStopR: nil
        )

        if let trade = openTrade {
            let price = PriceBook.shared.quote(for: trade.symbol)?.price

            snapshot.openSymbol = trade.symbol
            snapshot.openDirection = trade.direction.rawValue
            snapshot.openIsBE = trade.isBE
            snapshot.openPrice = price

            if let price, let distances = PriceMonitor.distances(trade, price: price) {
                snapshot.toTargetR = distances.toTargetR
                snapshot.toStopR = distances.toStopR
            } else {
                // Без рыночной цены показываем расстояние от входа — по плану сделки.
                snapshot.toTargetR = trade.plannedRR
                snapshot.toStopR = trade.isBE ? 0 : 1
            }
        }

        return snapshot
    }
}

/// Держит Live Activity цикла в актуальном состоянии и обновляет данные виджета.
@MainActor
final class CycleActivityController {
    static let shared = CycleActivityController()

    private init() {}

    func sync(context: ModelContext) {
        WidgetSnapshot.refresh(context: context)

        guard let snapshot = CycleLiveSnapshot.build(context: context) else {
            endAll()
            return
        }

        let attributes = CycleActivityAttributes(cycleStart: snapshot.cycleStart)
        let content = ActivityContent(state: snapshot.state, staleDate: snapshot.cycleEnd)

        apply(attributes: attributes, content: content)
    }

    private func apply(
        attributes: CycleActivityAttributes,
        content: ActivityContent<CycleActivityAttributes.ContentState>
    ) {
        let existing = Activity<CycleActivityAttributes>.activities

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAll()
            return
        }

        Task {
            if let activity = existing.first {
                await activity.update(content)

                for extra in existing.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
                return
            }

            do {
                _ = try Activity<CycleActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Live Activities недоступны на устройстве — молча выходим.
            }
        }
    }

    private func endAll() {
        let existing = Activity<CycleActivityAttributes>.activities
        guard !existing.isEmpty else { return }

        Task {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

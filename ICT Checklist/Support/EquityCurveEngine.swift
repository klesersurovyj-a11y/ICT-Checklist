//
//  EquityCurveEngine.swift
//  ICT Checklist
//
//  Кривая капитала в процентах и «подводная» кривая просадки.
//

import Foundation

enum EquityCurvePeriod: String, CaseIterable, Identifiable {
    case days30 = "30 дней"
    case days90 = "90 дней"
    case all = "Всё время"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .days30: return 30
        case .days90: return 90
        case .all: return nil
        }
    }
}

struct EquityCurvePoint: Identifiable {
    let id: Int
    let date: Date
    let percent: Double
}

struct DrawdownPoint: Identifiable {
    let id: Int
    let date: Date
    /// Просадка в процентах: 0 или положительное число.
    let percent: Double
}

struct EquityDayResult: Identifiable {
    let id: String
    let date: Date
    let percent: Double
    let trades: Int
}

struct EquityCurveReport {
    var points: [EquityCurvePoint] = []
    var drawdown: [DrawdownPoint] = []

    var capital = 0.0
    var startCapital = 0.0
    var totalPercent = 0.0
    var totalMoney = 0.0

    var maxCapital = 0.0
    var maxCapitalDate: Date?

    var maxDrawdownPercent = 0.0
    var maxDrawdownMoney = 0.0
    var currentDrawdownPercent = 0.0
    var currentDrawdownDays = 0
    var recoveryFactor = 0.0

    var bestDay: EquityDayResult?
    var worstDay: EquityDayResult?

    var tradesCount = 0

    var isEmpty: Bool { points.count <= 1 }
}

enum EquityCurveEngine {
    static func report(
        accounts: [TradingAccount],
        trades: [Trade],
        scope: TradingAccount?,
        period: EquityCurvePeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> EquityCurveReport {
        var result = EquityCurveReport()

        let today = calendar.startOfDay(for: now)
        let periodStart: Date? = {
            guard let days = period.days else { return nil }
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }()

        let allClosed = trades
            .filter { $0.result != .open }
            .filter { trade in
                guard let scope else { return true }
                return trade.account?.persistentModelID == scope.persistentModelID
            }
            .sorted { closeDate($0) < closeDate($1) }

        let closed: [Trade]
        if let periodStart {
            closed = allClosed.filter { closeDate($0) >= periodStart }
        } else {
            closed = allClosed
        }

        let totalCapital: Double
        if let scope {
            totalCapital = scope.equity
        } else {
            totalCapital = accounts
                .filter { !$0.isArchived }
                .reduce(0) { $0 + $1.equity }
        }

        let periodMoney = closed.reduce(0) { $0 + $1.riskUSD * $1.actualR }
        let startCapital = totalCapital - periodMoney

        result.capital = totalCapital
        result.startCapital = startCapital
        result.totalMoney = periodMoney
        result.tradesCount = closed.count
        if startCapital > 0.01 {
            result.totalPercent = periodMoney / startCapital * 100
        }

        guard startCapital > 0.01, let firstTrade = closed.first else {
            result.maxCapital = totalCapital
            result.maxCapitalDate = closed.last.map(closeDate)
            result.currentDrawdownPercent = 0
            return result
        }

        let startDate = calendar.startOfDay(for: closeDate(firstTrade))
        result.points.append(EquityCurvePoint(id: 0, date: startDate, percent: 0))
        result.drawdown.append(DrawdownPoint(id: 0, date: startDate, percent: 0))

        var running = startCapital
        var peakMoney = startCapital
        var peakDate = startDate
        var lastDrawdown = 0.0
        var maxDrawdownMoney = 0.0

        for (index, trade) in closed.enumerated() {
            running += trade.riskUSD * trade.actualR
            let percent = (running / startCapital - 1) * 100
            let date = closeDate(trade)

            result.points.append(EquityCurvePoint(id: index + 1, date: date, percent: percent))

            if running >= peakMoney {
                peakMoney = running
                peakDate = date
            }

            let drawdownPercent = peakMoney > 0.01 ? (peakMoney - running) / peakMoney * 100 : 0
            lastDrawdown = drawdownPercent
            result.drawdown.append(DrawdownPoint(id: index + 1, date: date, percent: drawdownPercent))

            maxDrawdownMoney = max(maxDrawdownMoney, peakMoney - running)
            result.maxDrawdownPercent = max(result.maxDrawdownPercent, drawdownPercent)
        }

        result.maxDrawdownMoney = max(maxDrawdownMoney, 0)
        result.maxCapital = peakMoney
        result.maxCapitalDate = peakDate
        result.currentDrawdownPercent = max(0, lastDrawdown)
        result.recoveryFactor = result.maxDrawdownMoney > 0.01 ? periodMoney / result.maxDrawdownMoney : 0

        if result.currentDrawdownPercent > 0.05 {
            let peakDay = calendar.startOfDay(for: peakDate)
            result.currentDrawdownDays = max(
                calendar.dateComponents([.day], from: peakDay, to: today).day ?? 0,
                0
            )
        }

        // Результат по дням закрытия.
        var byDay: [Date: (money: Double, count: Int)] = [:]
        for trade in closed {
            let day = calendar.startOfDay(for: closeDate(trade))
            var item = byDay[day] ?? (0, 0)
            item.money += trade.riskUSD * trade.actualR
            item.count += 1
            byDay[day] = item
        }

        let days = byDay
            .map { day, value in
                EquityDayResult(
                    id: "\(day.timeIntervalSince1970)",
                    date: day,
                    percent: startCapital > 0.01 ? value.money / startCapital * 100 : 0,
                    trades: value.count
                )
            }
            .sorted { $0.date > $1.date }

        result.bestDay = days.max { $0.percent < $1.percent }
        result.worstDay = days.min { $0.percent < $1.percent }

        return result
    }

    static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

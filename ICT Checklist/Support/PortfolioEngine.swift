//
//  PortfolioEngine.swift
//  ICT Checklist
//
//  Портфельная панель: капитал, открытый риск, просадка и риск-бюджет
//  месяца по всем счетам сразу или по одному выбранному.
//

import Foundation
import SwiftData

struct PortfolioAccountSlice: Identifiable {
    let id: String
    let name: String
    let equity: Double
    let share: Double
    let monthR: Double
    let isSelected: Bool
}

struct PortfolioReport {
    var capital = 0.0
    var startCapital = 0.0
    var equityR = 0.0
    var totalPercent = 0.0

    var monthR = 0.0
    var weekR = 0.0
    var dayR = 0.0
    var monthMoney = 0.0
    var monthPercent = 0.0

    var openRiskUSD = 0.0
    var openRiskPercent = 0.0

    var drawdownPercent = 0.0
    var drawdownMoney = 0.0

    var riskBudgetR = 0.0
    var riskUsedR = 0.0
    var weeklyLimitR = 0.0
    var weeksInMonth = 0
    var daysLeft = 0

    var closedCount = 0
    var slices: [PortfolioAccountSlice] = []

    /// Доля использованного риск-бюджета месяца, 0...1.
    var budgetShare: Double {
        guard riskBudgetR > 0.01 else { return 0 }
        return min(max(riskUsedR / riskBudgetR, 0), 1)
    }
}

enum PortfolioEngine {
    static func report(
        accounts: [TradingAccount],
        trades: [Trade],
        settings: AppSettings?,
        scope: TradingAccount?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PortfolioReport {
        let active = accounts.filter { !$0.isArchived }
        let scopeKey = scope.map { "\($0.persistentModelID)" }

        let scopedTrades: [Trade]
        if let scope {
            scopedTrades = trades.filter { $0.account?.persistentModelID == scope.persistentModelID }
        } else {
            scopedTrades = trades
        }

        let closed = scopedTrades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }
        let open = scopedTrades.filter { $0.result == .open }

        var report = PortfolioReport()
        report.closedCount = closed.count

        let fundCapital = active.reduce(0) { $0 + $1.equity }
        report.capital = scope?.equity ?? fundCapital

        let allMoney = closed.reduce(0) { $0 + $1.riskUSD * $1.actualR }
        report.startCapital = report.capital - allMoney
        report.equityR = closed.reduce(0) { $0 + $1.actualR }
        if report.startCapital > 0.01 {
            report.totalPercent = (report.capital - report.startCapital) / report.startCapital * 100
        }

        // Просадка от пика капитала по закрытым сделкам.
        if report.startCapital > 0.01 {
            var running = report.startCapital
            var peak = running
            for trade in closed {
                running += trade.riskUSD * trade.actualR
                peak = max(peak, running)
            }
            report.drawdownMoney = max(0, peak - running)
            report.drawdownPercent = peak > 0.01 ? report.drawdownMoney / peak * 100 : 0
        }

        // Результат дня, недели и месяца.
        let monthStart = startOfMonth(now, calendar)
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let dayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        let monthTrades = closed.filter { date in
            let closedAt = closeDate(date)
            return closedAt >= monthStart && closedAt < monthEnd
        }
        report.monthR = monthTrades.reduce(0) { $0 + $1.actualR }
        report.monthMoney = monthTrades.reduce(0) { $0 + $1.riskUSD * $1.actualR }
        if report.capital > 0.01 {
            report.monthPercent = report.monthMoney / report.capital * 100
        }
        report.weekR = closed
            .filter { closeDate($0) >= weekStart }
            .reduce(0) { $0 + $1.actualR }
        report.dayR = closed
            .filter { closeDate($0) >= dayStart }
            .reduce(0) { $0 + $1.actualR }

        // Открытый риск.
        report.openRiskUSD = open.reduce(0) { $0 + max($1.riskUSD, 0) }
        if report.capital > 0.01 {
            report.openRiskPercent = report.openRiskUSD / report.capital * 100
        }

        // Риск-бюджет месяца: недельный лимит, умноженный на число недель.
        let weeklyLimit = max(settings?.maxWeeklyLossR ?? 6, 1)
        let weeks = weeksInMonth(now, calendar)
        report.weeklyLimitR = weeklyLimit
        report.weeksInMonth = weeks
        report.riskBudgetR = weeklyLimit * Double(weeks)
        report.riskUsedR = max(0, -report.monthR)
        report.daysLeft = daysLeftInMonth(now, calendar)

        // Распределение капитала по счетам фонда.
        let fundMonthTrades = trades.filter { trade in
            guard trade.result != .open else { return false }
            let closedAt = closeDate(trade)
            return closedAt >= monthStart && closedAt < monthEnd
        }

        report.slices = active
            .map { account in
                let key = "\(account.persistentModelID)"
                let monthR = fundMonthTrades
                    .filter { $0.account?.persistentModelID == account.persistentModelID }
                    .reduce(0) { $0 + $1.actualR }
                return PortfolioAccountSlice(
                    id: key,
                    name: account.name.isEmpty ? account.type.rawValue : account.name,
                    equity: account.equity,
                    share: fundCapital > 0.01 ? max(0, account.equity) / fundCapital : 0,
                    monthR: monthR,
                    isSelected: key == scopeKey
                )
            }
            .sorted { $0.equity > $1.equity }

        return report
    }

    static func percentText(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0%" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f%%", abs(value))
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }

    private static func startOfMonth(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func weeksInMonth(_ date: Date, _ calendar: Calendar) -> Int {
        let start = startOfMonth(date, calendar)
        guard let days = calendar.range(of: .day, in: .month, for: start) else { return 4 }
        var weeks = Set<Int>()
        for day in days {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            weeks.insert(calendar.component(.weekOfYear, from: dayDate))
        }
        return max(weeks.count, 1)
    }

    private static func daysLeftInMonth(_ now: Date, _ calendar: Calendar) -> Int {
        let start = startOfMonth(now, calendar)
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return 0 }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: end).day ?? 0
        return max(days, 0)
    }
}

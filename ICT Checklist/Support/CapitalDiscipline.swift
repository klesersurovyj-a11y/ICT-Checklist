//
//  CapitalDiscipline.swift
//  ICT Checklist
//
//  Контрфактическая книга: сколько R стоит своеволие и каким был бы
//  результат, если бы сделок вне системы не брали.
//

import Foundation
import SwiftData

/// Нарушение, собранное из непройденных пунктов чек-листа сделок вне системы.
struct DisciplineViolation: Identifiable {
    var id: String { item.rawValue }
    let item: TradeCheck
    let costR: Double
    let count: Int
}

/// Неделя книги: убыток от нарушений и чистый результат по системе.
struct DisciplinePeriod: Identifiable {
    var id: Date { start }
    let start: Date
    let label: String
    let violationR: Double
    let cleanR: Double

    var isLoss: Bool { violationR < -0.05 }

    /// Что показывать столбиком: убыток от нарушений или чистый R недели.
    var barValue: Double {
        isLoss ? abs(violationR) : max(cleanR, 0)
    }
}

/// Инструмент: сколько сделок вне системы и сколько R они стоят.
struct DisciplineInstrument: Identifiable {
    var id: String { symbol }
    let symbol: String
    let outsideCount: Int
    let violationR: Double
}

struct DisciplineReport {
    var hasData = false

    var realR = 0.0
    var cleanR = 0.0
    var violationR = 0.0

    var outsideCount = 0
    var systemCount = 0

    var percentOfCapital = 0.0
    var realDrawdownPercent = 0.0
    var cleanDrawdownPercent = 0.0

    var violations: [DisciplineViolation] = []
    var periods: [DisciplinePeriod] = []
    var instruments: [DisciplineInstrument] = []
}

enum CapitalDiscipline {
    static func report(
        trades: [Trade],
        capital: Double,
        startCapital: Double,
        now: Date = .now,
        weeks: Int = 8,
        calendar: Calendar = .current
    ) -> DisciplineReport {
        var report = DisciplineReport()

        let closed = trades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }
        guard !closed.isEmpty else { return report }

        let outside = closed.filter { !$0.checklistComplete }
        let system = closed.filter { $0.checklistComplete }

        report.hasData = true
        report.realR = closed.reduce(0) { $0 + $1.actualR }
        report.cleanR = system.reduce(0) { $0 + $1.actualR }
        report.violationR = outside.reduce(0) { $0 + $1.actualR }
        report.outsideCount = outside.count
        report.systemCount = system.count

        let base = startCapital > 0.01 ? startCapital : capital
        if base > 0.01 {
            let money = outside.reduce(0) { $0 + $1.riskUSD * $1.actualR }
            report.percentOfCapital = money / base * 100
        }

        if startCapital > 0.01 {
            report.realDrawdownPercent = drawdownPercent(closed, startCapital: startCapital)
            report.cleanDrawdownPercent = drawdownPercent(system, startCapital: startCapital)
        }

        report.violations = TradeCheck.allCases.compactMap { item in
            let missing = outside.filter { !$0.checkedChecks.contains(item) }
            guard !missing.isEmpty else { return nil }
            let cost = missing.reduce(0) { $0 + $1.actualR }
            return DisciplineViolation(item: item, costR: cost, count: missing.count)
        }
        .sorted { $0.costR < $1.costR }

        report.instruments = Dictionary(grouping: outside, by: { $0.symbol.uppercased() })
            .map { symbol, list in
                DisciplineInstrument(
                    symbol: symbol.isEmpty ? "—" : symbol,
                    outsideCount: list.count,
                    violationR: list.reduce(0) { $0 + $1.actualR }
                )
            }
            .sorted { $0.violationR < $1.violationR }

        report.periods = periods(
            from: closed,
            now: now,
            weeks: weeks,
            calendar: calendar
        )

        return report
    }

    private static func periods(
        from closed: [Trade],
        now: Date,
        weeks: Int,
        calendar: Calendar
    ) -> [DisciplinePeriod] {
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var result: [DisciplinePeriod] = []

        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: endWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else {
                continue
            }

            let inWeek = closed.filter { trade in
                let date = closeDate(trade)
                return date >= start && date < end
            }
            let violations = inWeek.filter { !$0.checklistComplete }
            let clean = inWeek.filter { $0.checklistComplete }

            result.append(
                DisciplinePeriod(
                    start: start,
                    label: Fmt.dayMonth(start),
                    violationR: violations.reduce(0) { $0 + $1.actualR },
                    cleanR: clean.reduce(0) { $0 + $1.actualR }
                )
            )
        }

        return result
    }

    private static func drawdownPercent(_ trades: [Trade], startCapital: Double) -> Double {
        guard startCapital > 0.01 else { return 0 }
        var equity = startCapital
        var peak = startCapital
        var drawdown = 0.0

        for trade in trades {
            equity += trade.riskUSD * trade.actualR
            peak = max(peak, equity)
            drawdown = max(drawdown, peak - equity)
        }

        return peak > 0.01 ? drawdown / peak * 100 : 0
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

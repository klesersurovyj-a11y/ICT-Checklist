//
//  DisciplineStats.swift
//  ICT Checklist
//
//  Дисциплина системы: сделки по чек-листу против сделок вне его.
//

import Foundation

struct DisciplineWeek: Identifiable {
    var id: Date { start }
    let start: Date
    let label: String
    let share: Double
    let systemCount: Int
    let outsideCount: Int
}

struct DisciplineCheckStat: Identifiable {
    var id: String { item.rawValue }
    let item: TradeCheck
    let missed: Int
    let costR: Double
}

struct DisciplineSummary {
    var closedCount = 0
    var systemCount = 0
    var outsideCount = 0
    var share = 0.0

    var systemAvgR = 0.0
    var outsideAvgR = 0.0
    var systemWinRate = 0
    var outsideWinRate = 0

    var weeks: [DisciplineWeek] = []
    var checks: [DisciplineCheckStat] = []

    var hasData: Bool { closedCount > 0 }
}

enum DisciplineEngine {
    static func summary(
        trades: [Trade],
        now: Date = .now,
        weeks: Int = 8,
        calendar: Calendar = .current
    ) -> DisciplineSummary {
        var summary = DisciplineSummary()

        let closed = trades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }
        guard !closed.isEmpty else { return summary }

        let system = closed.filter { $0.checklistComplete }
        let outside = closed.filter { !$0.checklistComplete }

        summary.closedCount = closed.count
        summary.systemCount = system.count
        summary.outsideCount = outside.count
        summary.share = Double(system.count) / Double(closed.count)

        summary.systemAvgR = averageR(system)
        summary.outsideAvgR = averageR(outside)
        summary.systemWinRate = winRate(system)
        summary.outsideWinRate = winRate(outside)

        summary.weeks = weekly(
            closed,
            now: now,
            weeks: weeks,
            calendar: calendar
        )

        summary.checks = TradeCheck.allCases.compactMap { item in
            let missed = closed.filter { !$0.checkedChecks.contains(item) }
            guard !missed.isEmpty else { return nil }
            return DisciplineCheckStat(
                item: item,
                missed: missed.count,
                costR: missed.reduce(0) { $0 + $1.actualR }
            )
        }
        .sorted { $0.missed > $1.missed }

        return summary
    }

    private static func weekly(
        _ closed: [Trade],
        now: Date,
        weeks: Int,
        calendar: Calendar
    ) -> [DisciplineWeek] {
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var result: [DisciplineWeek] = []

        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: endWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else {
                continue
            }

            let inWeek = closed.filter { trade in
                let date = closeDate(trade)
                return date >= start && date < end
            }
            let system = inWeek.filter { $0.checklistComplete }.count
            let outside = inWeek.count - system
            let share = inWeek.isEmpty ? 0 : Double(system) / Double(inWeek.count)

            result.append(
                DisciplineWeek(
                    start: start,
                    label: Fmt.dayMonth(start),
                    share: share,
                    systemCount: system,
                    outsideCount: outside
                )
            )
        }

        return result
    }

    private static func averageR(_ trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return trades.reduce(0) { $0 + $1.actualR } / Double(trades.count)
    }

    private static func winRate(_ trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let wins = trades.filter { $0.actualR > 0.05 }.count
        return Int((Double(wins) / Double(trades.count) * 100).rounded())
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

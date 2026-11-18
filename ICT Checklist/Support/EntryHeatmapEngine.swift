//
//  EntryHeatmapEngine.swift
//  ICT Checklist
//
//  Часы входа: сколько R приносят сделки в каждый час и день недели.
//

import Foundation

enum EntryHeatPeriod: String, CaseIterable, Identifiable {
    case days30 = "30 дней"
    case days90 = "90 дней"
    case all = "Всё"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .days30: return 30
        case .days90: return 90
        case .all: return nil
        }
    }
}

struct EntryHeatCell: Identifiable {
    /// 0 — понедельник, 6 — воскресенье.
    let weekday: Int
    let hour: Int
    let trades: Int
    let wins: Int
    let totalR: Double

    var id: String { "\(weekday)-\(hour)" }

    var averageR: Double {
        trades > 0 ? totalR / Double(trades) : 0
    }

    var winRate: Int {
        trades > 0 ? Int((Double(wins) / Double(trades) * 100).rounded()) : 0
    }
}

struct EntryHourStat: Identifiable {
    let hour: Int
    let trades: Int
    let wins: Int
    let totalR: Double

    var id: Int { hour }

    var averageR: Double {
        trades > 0 ? totalR / Double(trades) : 0
    }

    var winRate: Int {
        trades > 0 ? Int((Double(wins) / Double(trades) * 100).rounded()) : 0
    }
}

struct EntryHeatReport {
    let period: EntryHeatPeriod
    let closed: [Trade]
    let cells: [EntryHeatCell]
    let hours: [EntryHourStat]
    let maxAbsR: Double

    static let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    static func build(
        trades: [Trade],
        period: EntryHeatPeriod,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> EntryHeatReport {
        let start: Date? = {
            guard let days = period.days else { return nil }
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }()

        let closed = trades.filter { trade in
            guard trade.result != .open else { return false }
            guard let start else { return true }
            return trade.entryDate >= start
        }

        var counts: [Int: Int] = [:]
        var wins: [Int: Int] = [:]
        var totals: [Int: Double] = [:]

        for trade in closed {
            let parts = calendar.dateComponents([.weekday, .hour], from: trade.entryDate)
            let rawWeekday = parts.weekday ?? 1
            let weekday = (rawWeekday + 5) % 7
            let hour = min(max(parts.hour ?? 0, 0), 23)
            let key = weekday * 24 + hour

            counts[key, default: 0] += 1
            totals[key, default: 0] += trade.actualR
            if trade.actualR > 0.05 {
                wins[key, default: 0] += 1
            }
        }

        var cells: [EntryHeatCell] = []
        cells.reserveCapacity(7 * 24)

        for weekday in 0..<7 {
            for hour in 0..<24 {
                let key = weekday * 24 + hour
                cells.append(
                    EntryHeatCell(
                        weekday: weekday,
                        hour: hour,
                        trades: counts[key] ?? 0,
                        wins: wins[key] ?? 0,
                        totalR: totals[key] ?? 0
                    )
                )
            }
        }

        var hourCounts: [Int: Int] = [:]
        var hourWins: [Int: Int] = [:]
        var hourTotals: [Int: Double] = [:]

        for trade in closed {
            let hour = min(max(calendar.component(.hour, from: trade.entryDate), 0), 23)
            hourCounts[hour, default: 0] += 1
            hourTotals[hour, default: 0] += trade.actualR
            if trade.actualR > 0.05 {
                hourWins[hour, default: 0] += 1
            }
        }

        let hours = (0..<24).map { hour in
            EntryHourStat(
                hour: hour,
                trades: hourCounts[hour] ?? 0,
                wins: hourWins[hour] ?? 0,
                totalR: hourTotals[hour] ?? 0
            )
        }

        let maxAbs = cells.map { abs($0.totalR) }.max() ?? 0

        return EntryHeatReport(
            period: period,
            closed: closed,
            cells: cells,
            hours: hours,
            maxAbsR: maxAbs > 0 ? maxAbs : 1
        )
    }

    var bestHours: [EntryHourStat] {
        hours
            .filter { $0.trades > 0 && $0.totalR > 0.05 }
            .sorted { $0.totalR > $1.totalR }
            .prefix(3)
            .map { $0 }
    }

    var worstHours: [EntryHourStat] {
        hours
            .filter { $0.trades > 0 && $0.totalR < -0.05 }
            .sorted { $0.totalR < $1.totalR }
            .prefix(3)
            .map { $0 }
    }

    func cell(weekday: Int, hour: Int) -> EntryHeatCell {
        cells.first { $0.weekday == weekday && $0.hour == hour }
            ?? EntryHeatCell(weekday: weekday, hour: hour, trades: 0, wins: 0, totalR: 0)
    }

    func hourStat(_ hour: Int) -> EntryHourStat {
        hours.first { $0.hour == hour }
            ?? EntryHourStat(hour: hour, trades: 0, wins: 0, totalR: 0)
    }

    /// Сделки выбранной клетки или часа.
    func trades(weekday: Int?, hour: Int, calendar: Calendar = .current) -> [Trade] {
        closed.filter { trade in
            let parts = calendar.dateComponents([.weekday, .hour], from: trade.entryDate)
            guard (parts.hour ?? 0) == hour else { return false }
            guard let weekday else { return true }
            return ((parts.weekday ?? 1) + 5) % 7 == weekday
        }
    }
}

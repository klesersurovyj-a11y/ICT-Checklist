//
//  TradeDurationEngine.swift
//  ICT Checklist
//
//  Время в сделке: распределение закрытых сделок по времени удержания.
//

import Foundation

struct DurationGroup: Identifiable {
    let title: String
    let fromHours: Double
    let toHours: Double?
    let trades: [Trade]

    var id: String { title }

    var count: Int { trades.count }

    var wins: Int {
        trades.filter { $0.actualR > 0.05 }.count
    }

    var winRate: Int {
        guard count > 0 else { return 0 }
        return Int((Double(wins) / Double(count) * 100).rounded())
    }

    var totalR: Double {
        trades.reduce(0) { $0 + $1.actualR }
    }

    var averageR: Double {
        count > 0 ? totalR / Double(count) : 0
    }

    func contains(hours: Double) -> Bool {
        hours >= fromHours && (toHours.map { hours < $0 } ?? true)
    }
}

struct TradeDurationReport {
    let period: EntryHeatPeriod
    let closed: [Trade]
    let groups: [DurationGroup]
    let averageToTPHours: Double?
    let averageToSLHours: Double?
    let fastPositiveShare: Int
    let slowCount: Int
    let slowAverageR: Double?

    static func build(
        trades: [Trade],
        period: EntryHeatPeriod,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> TradeDurationReport {
        let start: Date? = {
            guard let days = period.days else { return nil }
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }()

        let closed = trades.filter { trade in
            guard trade.result != .open, trade.closedAt != nil else { return false }
            guard let start else { return true }
            return trade.entryDate >= start
        }

        func holdingHours(_ trade: Trade) -> Double {
            guard let closedAt = trade.closedAt else { return 0 }
            return max(closedAt.timeIntervalSince(trade.entryDate) / 3600, 0)
        }

        let specs: [(String, Double, Double?)] = [
            ("до часа", 0, 1),
            ("1–4 часа", 1, 4),
            ("4–12 часов", 4, 12),
            ("12–24 часа", 12, 24),
            ("больше суток", 24, nil)
        ]

        let buckets: [DurationGroup] = specs.map { spec in
            let items = closed.filter { trade in
                let hours = holdingHours(trade)
                return hours >= spec.1 && (spec.2.map { hours < $0 } ?? true)
            }
            return DurationGroup(
                title: spec.0,
                fromHours: spec.1,
                toHours: spec.2,
                trades: items
            )
        }

        let tpTrades = closed.filter { $0.result == .tp }
        let slTrades = closed.filter { $0.result == .sl }

        let averageTP = tpTrades.isEmpty
            ? nil
            : tpTrades.map(holdingHours).reduce(0, +) / Double(tpTrades.count)
        let averageSL = slTrades.isEmpty
            ? nil
            : slTrades.map(holdingHours).reduce(0, +) / Double(slTrades.count)

        let fast = buckets.prefix(2).flatMap { $0.trades }
        let fastPositive = fast.filter { $0.actualR > 0.05 }.count
        let share = closed.isEmpty
            ? 0
            : Int((Double(fastPositive) / Double(closed.count) * 100).rounded())

        let slow = buckets.suffix(2).flatMap { $0.trades }
        let slowAverage = slow.isEmpty
            ? nil
            : slow.reduce(0) { $0 + $1.actualR } / Double(slow.count)

        return TradeDurationReport(
            period: period,
            closed: closed,
            groups: buckets,
            averageToTPHours: averageTP,
            averageToSLHours: averageSL,
            fastPositiveShare: share,
            slowCount: slow.count,
            slowAverageR: slowAverage
        )
    }

    var maxAbsR: Double {
        max(groups.map { abs($0.totalR) }.max() ?? 0, 0.1)
    }
}

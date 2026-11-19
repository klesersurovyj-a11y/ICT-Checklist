//
//  TagStatsEngine.swift
//  ICT Checklist
//
//  Статистика по тегам сделок: сделки, winrate, средний и суммарный R.
//

import Foundation

struct EntryTagStat: Identifiable {
    let title: String
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
}

enum TagStatsEngine {
    static func report(
        trades: [Trade],
        period: EntryHeatPeriod,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [EntryTagStat] {
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

        var buckets: [String: [Trade]] = [:]
        var order: [String] = []

        for trade in closed {
            for raw in trade.tags {
                let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !tag.isEmpty else { continue }
                if buckets[tag] == nil {
                    buckets[tag] = []
                    order.append(tag)
                }
                buckets[tag]?.append(trade)
            }
        }

        return order
            .compactMap { tag in
                guard let items = buckets[tag], !items.isEmpty else { return nil }
                return EntryTagStat(title: tag, trades: items)
            }
            .sorted { left, right in
                if abs(left.totalR - right.totalR) > 0.0001 {
                    return left.totalR > right.totalR
                }
                return left.count > right.count
            }
    }
}

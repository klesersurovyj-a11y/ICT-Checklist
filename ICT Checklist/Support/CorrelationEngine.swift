//
//  CorrelationEngine.swift
//  ICT Checklist
//
//  Корреляции инструментов по R и концентрация открытого риска.
//

import Foundation

enum CorrelationPeriod: String, CaseIterable, Identifiable {
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

struct CorrelationPair: Identifiable {
    let a: String
    let b: String
    let value: Double
    let commonDays: Int

    var id: String { "\(a)|\(b)" }
}

struct CorrelationConcentration {
    let symbol: String
    let riskUSD: Double
    /// Доля открытого риска в этом инструменте, 0...1.
    let share: Double
    /// Доля риска в одну сторону внутри этого инструмента, 0...1.
    let sameDirectionShare: Double
}

struct CorrelationGroup {
    let symbols: [String]
    let riskUSD: Double
    /// Доля открытого риска группы в общем открытом риске, 0...1.
    let share: Double
}

struct CorrelationWarning {
    let firstSymbol: String
    let firstDirection: Direction
    let secondSymbol: String
    let secondDirection: Direction
    let correlation: Double
    let riskUSD: Double
    let capitalShare: Double
}

struct CorrelationReport {
    var symbols: [String] = []
    var matrix: [String: [String: Double]] = [:]
    var commonDays: [String: Int] = [:]
    var observations: [String: Int] = [:]
    var topPair: CorrelationPair?
    var concentration: CorrelationConcentration?
    var group: CorrelationGroup?
    var warning: CorrelationWarning?
    var openTradesCount = 0
    var openRiskUSD = 0.0

    var isEmpty: Bool { symbols.count < 2 }

    func value(_ first: String, _ second: String) -> Double? {
        matrix[first]?[second]
    }

    func common(_ first: String, _ second: String) -> Int {
        commonDays["\(first)|\(second)"] ?? 0
    }
}

enum CorrelationEngine {
    static func report(
        trades: [Trade],
        accounts: [TradingAccount],
        period: CorrelationPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CorrelationReport {
        let start: Date? = {
            guard let days = period.days else { return nil }
            return calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now))
        }()

        let closed = trades.filter { trade in
            guard trade.result != .open else { return false }
            guard let start else { return true }
            return closeDate(trade) >= start
        }

        var result = CorrelationReport()

        // Дневной R по каждому инструменту.
        var daily: [String: [Date: Double]] = [:]
        var counts: [String: Int] = [:]
        for trade in closed {
            let day = calendar.startOfDay(for: closeDate(trade))
            daily[trade.symbol, default: [:]][day, default: 0] += trade.actualR
            counts[trade.symbol, default: 0] += 1
        }

        result.observations = counts
        let symbols = counts
            .filter { $0.value >= 2 }
            .sorted { first, second in
                if first.value == second.value { return first.key < second.key }
                return first.value > second.value
            }
            .prefix(5)
            .map(\.key)
        result.symbols = symbols

        var matrix: [String: [String: Double]] = [:]
        for symbol in symbols {
            matrix[symbol] = [symbol: 1]
        }

        var pairs: [CorrelationPair] = []
        for firstIndex in symbols.indices {
            for secondIndex in symbols.indices where secondIndex > firstIndex {
                let first = symbols[firstIndex]
                let second = symbols[secondIndex]
                let seriesA = daily[first] ?? [:]
                let seriesB = daily[second] ?? [:]
                let commonDates = Set(seriesA.keys).intersection(seriesB.keys)

                guard commonDates.count >= 3 else { continue }

                let valuesA = commonDates.compactMap { seriesA[$0] }
                let valuesB = commonDates.compactMap { seriesB[$0] }
                guard let value = correlation(valuesA, valuesB) else { continue }

                matrix[first]?[second] = value
                matrix[second]?[first] = value
                result.commonDays["\(first)|\(second)"] = commonDates.count
                result.commonDays["\(second)|\(first)"] = commonDates.count

                pairs.append(
                    CorrelationPair(a: first, b: second, value: value, commonDays: commonDates.count)
                )
            }
        }

        result.matrix = matrix
        result.topPair = pairs.sorted { abs($0.value) > abs($1.value) }.first

        // Концентрация открытого риска.
        let open = trades.filter { $0.result == .open }
        result.openTradesCount = open.count
        result.openRiskUSD = open.reduce(0) { $0 + max($1.riskUSD, 0) }

        if result.openRiskUSD > 0.01 {
            let bySymbol = Dictionary(grouping: open, by: \.symbol)
            let risks = bySymbol.mapValues { list in list.reduce(0) { $0 + max($1.riskUSD, 0) } }
            if let largest = risks.max(by: { $0.value < $1.value }) {
                let symbolTrades = bySymbol[largest.key] ?? []
                let longRisk = symbolTrades
                    .filter { $0.direction == .long }
                    .reduce(0) { $0 + max($1.riskUSD, 0) }
                let shortRisk = symbolTrades
                    .filter { $0.direction == .short }
                    .reduce(0) { $0 + max($1.riskUSD, 0) }

                result.concentration = CorrelationConcentration(
                    symbol: largest.key,
                    riskUSD: largest.value,
                    share: largest.value / result.openRiskUSD,
                    sameDirectionShare: max(longRisk, shortRisk) / result.openRiskUSD
                )
            }

            // Самая крупная группа связанных инструментов с открытым риском.
            let linked = pairs.filter { $0.value >= 0.5 }
            var visited: Set<String> = []
            var groups: [[String]] = []

            for symbol in risks.keys.sorted() where !visited.contains(symbol) {
                var stack = [symbol]
                var group: Set<String> = []

                while let next = stack.popLast() {
                    guard !group.contains(next) else { continue }
                    group.insert(next)
                    visited.insert(next)

                    for pair in linked {
                        if pair.a == next && !group.contains(pair.b) {
                            stack.append(pair.b)
                        }
                        if pair.b == next && !group.contains(pair.a) {
                            stack.append(pair.a)
                        }
                    }
                }

                if group.count >= 2 {
                    groups.append(group.sorted())
                }
            }

            result.group = groups
                .map { symbols in
                    let risk = symbols.reduce(0.0) { $0 + (risks[$1] ?? 0) }
                    return CorrelationGroup(
                        symbols: symbols,
                        riskUSD: risk,
                        share: risk / result.openRiskUSD
                    )
                }
                .filter { $0.riskUSD > 0.01 }
                .max { $0.share < $1.share }
        }

        // Открытые сделки в одну сторону по связанным инструментам.
        let capital = accounts
            .filter { !$0.isArchived }
            .reduce(0) { $0 + $1.equity }

        for pair in pairs.sorted(by: { abs($0.value) > abs($1.value) }) where pair.value >= 0.5 {
            let listA = open.filter { $0.symbol == pair.a }
            let listB = open.filter { $0.symbol == pair.b }

            for side in Direction.allCases {
                let tradesA = listA.filter { $0.direction == side }
                let tradesB = listB.filter { $0.direction == side }
                guard !tradesA.isEmpty, !tradesB.isEmpty else { continue }

                let risk = (tradesA + tradesB).reduce(0) { $0 + max($1.riskUSD, 0) }
                result.warning = CorrelationWarning(
                    firstSymbol: pair.a,
                    firstDirection: side,
                    secondSymbol: pair.b,
                    secondDirection: side,
                    correlation: pair.value,
                    riskUSD: risk,
                    capitalShare: capital > 0.01 ? risk / capital * 100 : 0
                )
                return result
            }
        }

        return result
    }

    static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }

    private static func correlation(_ a: [Double], _ b: [Double]) -> Double? {
        let n = min(a.count, b.count)
        guard n >= 3 else { return nil }

        let meanA = a.prefix(n).reduce(0, +) / Double(n)
        let meanB = b.prefix(n).reduce(0, +) / Double(n)

        var covariance = 0.0
        var varianceA = 0.0
        var varianceB = 0.0

        for index in 0..<n {
            let devA = a[index] - meanA
            let devB = b[index] - meanB
            covariance += devA * devB
            varianceA += devA * devA
            varianceB += devB * devB
        }

        let denominator = (varianceA * varianceB).squareRoot()
        guard denominator > 0.000001 else { return nil }
        return min(max(covariance / denominator, -1), 1)
    }
}

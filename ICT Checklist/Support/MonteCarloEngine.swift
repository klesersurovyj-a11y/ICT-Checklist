//
//  MonteCarloEngine.swift
//  ICT Checklist
//
//  Симуляция Монте-Карло по распределению R закрытых сделок.
//

import Foundation

enum MonteCarloPeriod: String, CaseIterable, Identifiable {
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

struct MonteCarloBin: Identifiable {
    let id: Int
    let lower: Double
    let upper: Double
    let count: Int

    var mid: Double { (lower + upper) / 2 }
}

struct MonteCarloReport {
    var runs = 0
    var horizon = 0
    var riskPercent = 0.0
    var poolSize = 0

    var medianR = 0.0
    var lowR = 0.0
    var highR = 0.0
    var expectedMaxDrawdownR = 0.0

    /// Доля путей, где капитал проседал хотя бы на 10% и 20%.
    var loss10Probability = 0.0
    var loss20Probability = 0.0
    /// Доля путей, где капитал терял половину.
    var ruinProbability = 0.0

    var bins: [MonteCarloBin] = []
    var minR = 0.0
    var maxR = 0.0

    var isEmpty: Bool { runs == 0 || bins.isEmpty }
}

enum MonteCarloEngine {
    static let defaultRuns = 1000

    static func report(
        pool: [Double],
        horizon: Int,
        riskPercent: Double,
        runs: Int = defaultRuns,
        seed: UInt64 = 0x1C7C0FFEE
    ) -> MonteCarloReport {
        guard pool.count >= 3, horizon > 0, runs > 0 else { return MonteCarloReport() }

        var result = MonteCarloReport()
        result.runs = runs
        result.horizon = horizon
        result.riskPercent = riskPercent
        result.poolSize = pool.count

        var rng = MonteCarloRandom(seed: seed)
        var finals: [Double] = []
        finals.reserveCapacity(runs)
        var drawdowns: [Double] = []
        drawdowns.reserveCapacity(runs)
        var loss10 = 0
        var loss20 = 0
        var ruin = 0

        let riskFraction = max(riskPercent, 0) / 100

        for _ in 0..<runs {
            var cumulativeR = 0.0
            var peakR = 0.0
            var maxDrawdownR = 0.0

            var equity = 1.0
            var peakEquity = 1.0
            var maxEquityDrawdown = 0.0

            for _ in 0..<horizon {
                let index = Int(rng.next() % UInt64(pool.count))
                let value = pool[index]

                cumulativeR += value
                peakR = max(peakR, cumulativeR)
                maxDrawdownR = max(maxDrawdownR, peakR - cumulativeR)

                equity *= max(0, 1 + riskFraction * value)
                peakEquity = max(peakEquity, equity)
                if peakEquity > 0.0001 {
                    maxEquityDrawdown = max(maxEquityDrawdown, (peakEquity - equity) / peakEquity)
                } else {
                    maxEquityDrawdown = 1
                    break
                }
            }

            finals.append(cumulativeR)
            drawdowns.append(maxDrawdownR)
            if maxEquityDrawdown >= 0.10 { loss10 += 1 }
            if maxEquityDrawdown >= 0.20 { loss20 += 1 }
            if maxEquityDrawdown >= 0.50 { ruin += 1 }
        }

        let sortedFinals = finals.sorted()
        result.lowR = percentile(sortedFinals, 0.05)
        result.medianR = percentile(sortedFinals, 0.5)
        result.highR = percentile(sortedFinals, 0.95)
        result.expectedMaxDrawdownR = percentile(drawdowns.sorted(), 0.5)

        result.loss10Probability = Double(loss10) / Double(runs)
        result.loss20Probability = Double(loss20) / Double(runs)
        result.ruinProbability = Double(ruin) / Double(runs)

        let minimum = sortedFinals.first ?? 0
        let maximum = sortedFinals.last ?? 0
        result.minR = minimum
        result.maxR = maximum
        result.bins = bins(values: sortedFinals, minimum: minimum, maximum: maximum)

        return result
    }

    static func formattedProbability(_ value: Double) -> String {
        guard value > 0 else { return "0%" }
        if value < 0.01 { return "<1%" }
        let percent = value * 100
        return "\(Int(percent.rounded()))%"
    }

    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = min(max(fraction, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private static func bins(values: [Double], minimum: Double, maximum: Double) -> [MonteCarloBin] {
        let count = 22
        let span = max(maximum - minimum, 0.01)
        let step = span / Double(count)

        var counts = [Int](repeating: 0, count: count)
        for value in values {
            var index = Int((value - minimum) / step)
            if index >= count { index = count - 1 }
            if index < 0 { index = 0 }
            counts[index] += 1
        }

        return (0..<count).map { index in
            MonteCarloBin(
                id: index,
                lower: minimum + step * Double(index),
                upper: minimum + step * Double(index + 1),
                count: counts[index]
            )
        }
    }
}

private struct MonteCarloRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

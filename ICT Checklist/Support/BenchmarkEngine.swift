//
//  BenchmarkEngine.swift
//  ICT Checklist
//
//  Сравнение капитала в R с рыночным бенчмарком.
//

import Foundation

enum BenchmarkKind: String, CaseIterable, Identifiable {
    case sp500 = "S&P 500"
    case gold = "Золото"
    case btc = "BTC"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .sp500: return "SPX"
        case .gold: return "XAU/USD"
        case .btc: return "BTC/USD"
        }
    }
}

struct BenchmarkPoint: Identifiable {
    let date: Date
    let trader: Double
    let benchmark: Double?

    var id: Date { date }
}

struct BenchmarkReport {
    let traderTotal: Double
    let traderWinRate: Int
    let traderMaxDD: Double
    let benchmarkTotalPct: Double?
    let benchmarkWinRate: Int?
    let benchmarkMaxDDPct: Double?
    let points: [BenchmarkPoint]

    var benchmarkAvailable: Bool {
        benchmarkTotalPct != nil
    }

    /// Разница в R: процент бенчмарка считаем один к одному.
    var diffR: Double? {
        guard let benchmarkTotalPct else { return nil }
        return traderTotal - benchmarkTotalPct
    }

    static let empty = BenchmarkReport(
        traderTotal: 0,
        traderWinRate: 0,
        traderMaxDD: 0,
        benchmarkTotalPct: nil,
        benchmarkWinRate: nil,
        benchmarkMaxDDPct: nil,
        points: []
    )
}

enum BenchmarkEngine {
    static func build(
        trades: [Trade],
        period: EntryHeatPeriod,
        bars: [ChartBar]?,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> BenchmarkReport {
        let start: Date? = {
            guard let days = period.days else { return nil }
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }()

        let closed = trades
            .filter { trade in
                guard trade.result != .open, trade.closedAt != nil else { return false }
                guard let start else { return true }
                return trade.entryDate >= start
            }
            .sorted { ($0.closedAt ?? $0.tradingDay) < ($1.closedAt ?? $1.tradingDay) }

        let traderTotal = closed.reduce(0) { $0 + $1.actualR }
        let wins = closed.filter { $0.actualR > 0.05 }.count
        let winRate = closed.isEmpty
            ? 0
            : Int((Double(wins) / Double(closed.count) * 100).rounded())

        let traderMaxDD = maxDrawdown(closed)

        let periodBars: [ChartBar] = {
            guard let bars, !bars.isEmpty else { return [] }
            guard let start else { return bars }
            let stamp = Int(start.timeIntervalSince1970)
            let filtered = bars.filter { $0.time >= stamp }
            return filtered.isEmpty ? bars : filtered
        }()

        guard let firstBar = periodBars.first, firstBar.close > 0 else {
            return BenchmarkReport(
                traderTotal: traderTotal,
                traderWinRate: winRate,
                traderMaxDD: traderMaxDD,
                benchmarkTotalPct: nil,
                benchmarkWinRate: nil,
                benchmarkMaxDDPct: nil,
                points: tradeOnlyPoints(closed: closed, start: start, now: now)
            )
        }

        var points: [BenchmarkPoint] = []

        for bar in periodBars {
            let date = Date(timeIntervalSince1970: TimeInterval(bar.time))
            let traderValue = closed
                .filter { ($0.closedAt ?? $0.tradingDay) <= date }
                .reduce(0) { $0 + $1.actualR }
            let percent = (bar.close / firstBar.close - 1) * 100
            points.append(
                BenchmarkPoint(date: date, trader: traderValue, benchmark: percent)
            )
        }

        // Последняя сделка может быть позже последней свечи.
        if let lastClose = closed.last?.closedAt ?? closed.last?.tradingDay,
           let lastDate = points.last?.date,
           lastClose > lastDate {
            let lastPercent = points.last?.benchmark
            points.append(
                BenchmarkPoint(date: lastClose, trader: traderTotal, benchmark: lastPercent)
            )
        }

        let lastCloseValue = periodBars.last?.close ?? firstBar.close
        let totalPct = (lastCloseValue / firstBar.close - 1) * 100

        var upDays = 0
        for index in 1..<max(periodBars.count, 1) {
            if periodBars[index].close > periodBars[index - 1].close {
                upDays += 1
            }
        }
        let benchWinRate = periodBars.count > 1
            ? Int((Double(upDays) / Double(periodBars.count - 1) * 100).rounded())
            : 0

        let benchMaxDD = maxDrawdownPercent(periodBars)

        return BenchmarkReport(
            traderTotal: traderTotal,
            traderWinRate: winRate,
            traderMaxDD: traderMaxDD,
            benchmarkTotalPct: totalPct,
            benchmarkWinRate: benchWinRate,
            benchmarkMaxDDPct: benchMaxDD,
            points: points
        )
    }

    // MARK: - Helpers

    private static func tradeOnlyPoints(
        closed: [Trade],
        start: Date?,
        now: Date
    ) -> [BenchmarkPoint] {
        var points: [BenchmarkPoint] = []
        if let start {
            points.append(BenchmarkPoint(date: start, trader: 0, benchmark: nil))
        }

        var cumulative = 0.0
        for trade in closed {
            cumulative += trade.actualR
            let date = trade.closedAt ?? trade.tradingDay
            points.append(BenchmarkPoint(date: date, trader: cumulative, benchmark: nil))
        }

        return points
    }

    private static func maxDrawdown(_ trades: [Trade]) -> Double {
        var peak = 0.0
        var cumulative = 0.0
        var worst = 0.0

        for trade in trades {
            cumulative += trade.actualR
            peak = max(peak, cumulative)
            worst = max(worst, peak - cumulative)
        }

        return worst
    }

    private static func maxDrawdownPercent(_ bars: [ChartBar]) -> Double {
        var peak = 0.0
        var worst = 0.0

        for bar in bars {
            peak = max(peak, bar.close)
            guard peak > 0 else { continue }
            worst = max(worst, (peak - bar.close) / peak * 100)
        }

        return worst
    }
}

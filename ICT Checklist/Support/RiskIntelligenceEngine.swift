//
//  RiskIntelligenceEngine.swift
//  ICT Checklist
//
//  Risk Intelligence: фактический риск, риск в процентах капитала,
//  просадка, дневной и недельный лимиты и контроль риск-лестницы.
//

import Foundation
import SwiftData

struct RiskWarning: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: BehaviorTone
}

/// Состояние одного лимита: сделки и результат против допустимых значений.
struct RiskLimitSnapshot {
    let title: String
    let isEnabled: Bool
    let trades: Int
    let maxTrades: Int
    let r: Double
    let maxLossR: Double

    var tradeProgress: Double {
        maxTrades > 0 ? min(max(Double(trades) / Double(maxTrades), 0), 1) : 0
    }

    var lossProgress: Double {
        maxLossR > 0 ? min(max(-r / maxLossR, 0), 1) : 0
    }

    var isReached: Bool {
        guard isEnabled else { return false }
        if trades >= maxTrades { return true }
        return r <= -maxLossR + 0.0001
    }

    var isNear: Bool {
        guard isEnabled, !isReached else { return false }
        if trades > 0, maxTrades - trades <= 1 { return true }
        return lossProgress >= 0.8
    }

    var tradesText: String { "\(trades)/\(maxTrades)" }

    var rText: String { "\(Fmt.r(r)) / \(Fmt.r(-maxLossR))" }
}

/// Сделка в разбивке по риску.
struct RiskTradeRow: Identifiable {
    let id: String
    let trade: Trade
    let riskUSD: Double
    let riskPercent: Double?
    let expectedUSD: Double
    /// Риск сделки относительно её ступени: 1.00 — ровно по системе.
    let riskR: Double

    var isMismatch: Bool { abs(riskUSD - expectedUSD) > 0.51 }
}

struct RiskLadderStep: Identifiable {
    let id: Int
    let step: Int
    let count: Int
    let totalR: Double
    let averageRisk: Double
}

struct RiskPoint: Identifiable {
    let id: Int
    let date: Date
    let value: Double
}

struct RiskReport {
    var closedCount = 0
    var averageRiskUSD: Double = 0
    var averageRiskR: Double = 0
    var medianRiskUSD: Double?
    var averageRiskPercent: Double?
    var overPercentCount = 0
    var maxRiskPercent = 1.0

    var equity: Double?
    var points: [RiskPoint] = []
    var currentR: Double = 0
    var peakR: Double = 0
    var currentDrawdownR: Double = 0
    var maxDrawdownR: Double = 0
    var currentDrawdownPercent: Double?
    var maxDrawdownPercent: Double?

    var daily: RiskLimitSnapshot?
    var weekly: RiskLimitSnapshot?

    var ladderStep = 0
    var ladderAccumulated: Double = 0
    var ladderTarget: Double = LadderSnapshot.targetR
    var ladderStats: [RiskLadderStep] = []
    var mismatches: [RiskTradeRow] = []
    var ladderMismatchCount = 0
    var recent: [RiskTradeRow] = []
    var warnings: [RiskWarning] = []
}

enum RiskIntelligenceEngine {
    static func report(
        trades: [Trade],
        settings: AppSettings?,
        accounts: [TradingAccount]
    ) -> RiskReport {
        let calendar = Calendar.current
        let closed = trades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }

        var result = RiskReport()
        result.closedCount = closed.count
        result.maxRiskPercent = max(settings?.maxRiskPercent ?? 1, 0.1)

        let amounts = settings?.ladderAmounts ?? [12, 25, 50]
        let maxDailyLossR = max(settings?.maxDailyLossR ?? 2, 0.5)
        let maxWeeklyLossR = max(settings?.maxWeeklyLossR ?? 6, 1)
        let maxTradesPerDay = max(settings?.maxTradesPerDay ?? 2, 1)
        let maxTradesPerWeek = max(settings?.maxTradesPerWeek ?? 10, 1)

        let equityMap = equityByAccount(accounts)
        let totalEquity = equityMap.values.reduce(0, +)
        result.equity = totalEquity > 0 ? totalEquity : nil

        // MARK: Риск по сделкам

        var rows: [RiskTradeRow] = []
        var riskValues: [Double] = []
        var percentValues: [Double] = []

        for trade in closed {
            let expected = amounts[min(max(trade.ladderStepIndex, 0), amounts.count - 1)]
            let denominator = equity(for: trade, equityMap: equityMap, fallback: result.equity)
            let percent = denominator.map { $0 > 0 ? trade.riskUSD / $0 * 100 : 0 }
            rows.append(
                RiskTradeRow(
                    id: "\(trade.persistentModelID)",
                    trade: trade,
                    riskUSD: trade.riskUSD,
                    riskPercent: percent,
                    expectedUSD: expected,
                    riskR: expected > 0 ? trade.riskUSD / expected : 0
                )
            )
            riskValues.append(trade.riskUSD)
            if let percent {
                percentValues.append(percent)
            }
        }

        result.mismatches = Array(rows.filter(\.isMismatch).suffix(5).reversed())
        result.ladderMismatchCount = rows.filter(\.isMismatch).count
        result.recent = Array(rows.suffix(8).reversed())

        if !riskValues.isEmpty {
            result.averageRiskUSD = riskValues.reduce(0, +) / Double(riskValues.count)
            result.averageRiskR = rows.reduce(0) { $0 + $1.riskR } / Double(rows.count)
            let sorted = riskValues.sorted()
            let middle = sorted.count / 2
            result.medianRiskUSD = sorted.count % 2 == 0
                ? (sorted[middle - 1] + sorted[middle]) / 2
                : sorted[middle]
        }

        if !percentValues.isEmpty {
            result.averageRiskPercent = percentValues.reduce(0, +) / Double(percentValues.count)
        }
        result.overPercentCount = rows.filter { ($0.riskPercent ?? 0) > result.maxRiskPercent + 0.0001 }.count

        // MARK: Просадка

        var cumulative = 0.0
        var peak = 0.0
        var maxDrawdown = 0.0
        var points: [RiskPoint] = []

        for (index, trade) in closed.enumerated() {
            cumulative += trade.actualR
            peak = max(peak, cumulative)
            maxDrawdown = max(maxDrawdown, peak - cumulative)
            points.append(RiskPoint(id: index, date: closeDate(trade), value: cumulative))
        }

        result.points = points
        result.currentR = cumulative
        result.peakR = peak
        result.currentDrawdownR = max(0, peak - cumulative)
        result.maxDrawdownR = maxDrawdown

        if let equityNow = result.equity {
            let moneyResult = closed.reduce(0) { $0 + $1.riskUSD * $1.actualR }
            let startEquity = equityNow - moneyResult
            var running = startEquity
            var equityPeak = startEquity
            var maxPercent = 0.0
            for trade in closed {
                running += trade.riskUSD * trade.actualR
                equityPeak = max(equityPeak, running)
                if equityPeak > 0.01 {
                    maxPercent = max(maxPercent, (equityPeak - running) / equityPeak * 100)
                }
            }
            result.maxDrawdownPercent = maxPercent
            if equityPeak > 0.01 {
                result.currentDrawdownPercent = max(0, (equityPeak - running) / equityPeak * 100)
            }
        }

        // MARK: Лимиты

        let startOfToday = calendar.startOfDay(for: .now)
        let weekStart = startOfWeek(for: .now, calendar: calendar)

        let todayTrades = trades.filter { $0.tradingDay >= startOfToday }
        let weekTrades = trades.filter { $0.tradingDay >= weekStart }

        result.daily = RiskLimitSnapshot(
            title: "Сегодня",
            isEnabled: settings?.dailyLimitsEnabled ?? false,
            trades: todayTrades.count,
            maxTrades: maxTradesPerDay,
            r: todayTrades.filter { $0.result != .open }.reduce(0) { $0 + $1.actualR },
            maxLossR: maxDailyLossR
        )

        result.weekly = RiskLimitSnapshot(
            title: "Неделя",
            isEnabled: settings?.weeklyLimitsEnabled ?? false,
            trades: weekTrades.count,
            maxTrades: maxTradesPerWeek,
            r: weekTrades.filter { $0.result != .open }.reduce(0) { $0 + $1.actualR },
            maxLossR: maxWeeklyLossR
        )

        // MARK: Лестница

        let ladder = LadderEngine.evaluate(trades: trades)
        result.ladderStep = min(max(ladder.stepIndex, 0), 2)
        result.ladderAccumulated = ladder.accumulatedR
        result.ladderTarget = LadderSnapshot.targetR
        result.ladderStats = (0..<amounts.count).map { index in
            let stepTrades = closed.filter { $0.ladderStepIndex == index }
            let totalR = stepTrades.reduce(0) { $0 + $1.actualR }
            let avgRisk = stepTrades.isEmpty
                ? 0
                : stepTrades.reduce(0) { $0 + $1.riskUSD } / Double(stepTrades.count)
            return RiskLadderStep(
                id: index,
                step: index,
                count: stepTrades.count,
                totalR: totalR,
                averageRisk: avgRisk
            )
        }

        result.warnings = warnings(for: result)
        return result
    }

    // MARK: - Предупреждения

    private static func warnings(for report: RiskReport) -> [RiskWarning] {
        var items: [RiskWarning] = []

        if let daily = report.daily, daily.isEnabled {
            if daily.isReached {
                items.append(
                    RiskWarning(
                        id: "daily-reached",
                        title: "Дневной лимит достигнут",
                        detail: "Сделок \(daily.tradesText), результат \(daily.rText). Новых входов быть не должно до следующего цикла.",
                        tone: .negative
                    )
                )
            } else if daily.isNear {
                items.append(
                    RiskWarning(
                        id: "daily-near",
                        title: "Дневной лимит почти исчерпан",
                        detail: "Сделок \(daily.tradesText), результат \(daily.rText). Следующий вход — только по системе.",
                        tone: .neutral
                    )
                )
            }
        }

        if let weekly = report.weekly, weekly.isEnabled {
            if weekly.isReached {
                items.append(
                    RiskWarning(
                        id: "weekly-reached",
                        title: "Недельный лимит достигнут",
                        detail: "Сделок \(weekly.tradesText), результат \(weekly.rText). Стоит остановиться до следующей недели.",
                        tone: .negative
                    )
                )
            } else if weekly.isNear {
                items.append(
                    RiskWarning(
                        id: "weekly-near",
                        title: "Недельный лимит близко",
                        detail: "Сделок \(weekly.tradesText), результат \(weekly.rText).",
                        tone: .neutral
                    )
                )
            }
        }

        if report.overPercentCount > 0 {
            items.append(
                RiskWarning(
                    id: "risk-percent",
                    title: "Риск выше \(percentText(report.maxRiskPercent)) капитала",
                    detail: "Так открыто \(report.overPercentCount) \(dealsWord(report.overPercentCount)). Средний риск — \(percentText(report.averageRiskPercent ?? 0)).",
                    tone: .negative
                )
            )
        }

        if report.ladderMismatchCount > 0 {
            let worst = report.mismatches[0]
            items.append(
                RiskWarning(
                    id: "ladder-mismatch",
                    title: "Риск не по ступени",
                    detail: "\(report.ladderMismatchCount) \(dealsWord(report.ladderMismatchCount)) с риском, отличным от лестницы. Например \(worst.trade.symbol): \(Fmt.money(worst.riskUSD)) вместо \(Fmt.money(worst.expectedUSD)).",
                    tone: .negative
                )
            )
        }

        if report.currentDrawdownR >= 2 * (report.daily?.maxLossR ?? 2) {
            items.append(
                RiskWarning(
                    id: "drawdown",
                    title: "Просадка \(Fmt.r(-report.currentDrawdownR))",
                    detail: "От пика \(Fmt.r(report.peakR)) до текущего \(Fmt.r(report.currentR)). Это больше двух дневных лимитов — уменьшите риск или остановитесь.",
                    tone: .negative
                )
            )
        }

        if items.isEmpty {
            items.append(
                RiskWarning(
                    id: "ok",
                    title: "Риск под контролем",
                    detail: "Лимиты не нарушены, риск на сделку в пределах \(percentText(report.maxRiskPercent)) капитала, риск-лестница соблюдается.",
                    tone: .positive
                )
            )
        }

        let priority: [BehaviorTone: Int] = [.negative: 0, .neutral: 1, .positive: 2]
        return items.sorted { (priority[$0.tone] ?? 3) < (priority[$1.tone] ?? 3) }
    }

    // MARK: - Помощники

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }

    private static func equityByAccount(_ accounts: [TradingAccount]) -> [PersistentIdentifier: Double] {
        var map: [PersistentIdentifier: Double] = [:]
        for account in accounts {
            let moneyResult = account.trades
                .filter { $0.result != .open }
                .reduce(0) { $0 + $1.riskUSD * $1.actualR }
            map[account.persistentModelID] = account.balance + moneyResult
        }
        return map
    }

    private static func equity(
        for trade: Trade,
        equityMap: [PersistentIdentifier: Double],
        fallback: Double?
    ) -> Double? {
        if let account = trade.account,
           let value = equityMap[account.persistentModelID],
           value > 0 {
            return value
        }
        if let fallback, fallback > 0 {
            return fallback
        }
        return nil
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    static func percentText(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    static func signedPercent(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "\u{2212}")\(String(format: "%.2f", abs(value)))%"
    }

    private static func dealsWord(_ count: Int) -> String {
        Fmt.dealWord(count)
    }

    static func promptSummary(_ report: RiskReport) -> String {
        var lines: [String] = []
        lines.append(
            "Закрытых сделок: \(report.closedCount). Средний риск \(Fmt.money(report.averageRiskUSD)), средний риск в капитале \(percentText(report.averageRiskPercent ?? 0)), риск относительно ступени \(String(format: "%.2f", report.averageRiskR))R, лимит \(percentText(report.maxRiskPercent))."
        )
        lines.append(
            "Просадка: сейчас \(Fmt.r(-report.currentDrawdownR)), максимум \(Fmt.r(-report.maxDrawdownR)), капитал \(report.equity.map { Fmt.money($0) } ?? "—"), просадка в процентах \(report.currentDrawdownPercent.map(percentText) ?? "—"), максимум \(report.maxDrawdownPercent.map(percentText) ?? "—")."
        )
        if let daily = report.daily {
            lines.append("День: \(daily.title), сделок \(daily.tradesText), результат \(daily.rText), лимиты \(daily.isEnabled ? "включены" : "выключены").")
        }
        if let weekly = report.weekly {
            lines.append("Неделя: сделок \(weekly.tradesText), результат \(weekly.rText), лимиты \(weekly.isEnabled ? "включены" : "выключены").")
        }
        lines.append(
            "Риск-лестница: ступень \(report.ladderStep + 1), накоплено \(String(format: "%.2f", report.ladderAccumulated)) из \(String(format: "%.1f", report.ladderTarget)) R, нарушений \(report.ladderMismatchCount)."
        )
        for warning in report.warnings {
            lines.append("\(warning.title): \(warning.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

//
//  MonthlyPerformanceEngine.swift
//  ICT Checklist
//
//  Месячный разбор в стиле AlexxxFX (THE EDGE):
//  качество преимущества, нарратив, асимметрия, дисциплина риска.
//

import Foundation
import SwiftData

enum AlexEdgeState {
    case insufficient
    case working
    case fragile
    case broken

    var title: String {
        switch self {
        case .insufficient: return "Мало данных"
        case .working: return "Edge работает"
        case .fragile: return "Edge под вопросом"
        case .broken: return "Edge не работает"
        }
    }

    var detail: String {
        switch self {
        case .insufficient:
            return "Меньше пяти закрытых сделок — статистика месяца ещё ничего не доказывает."
        case .working:
            return "Profit factor и expectancy держатся выше порога: сетапы дают преимущество."
        case .fragile:
            return "Результат положительный, но profit factor ниже 1.5 — преимущество держится на тонком крае."
        case .broken:
            return "Profit factor ниже 1 или expectancy отрицательный: сетап без преимущества — не edge."
        }
    }
}

struct MonthScore: Identifiable {
    let id: String
    let title: String
    let detail: String
    let value: Double

    var points: Int {
        Int((max(0, min(value, 1)) * 20).rounded())
    }
}

struct MonthWeek: Identifiable {
    let id: Date
    let label: String
    let trades: Int
    let totalR: Double
    let winRate: Double
}

struct MonthGroup: Identifiable {
    let id: String
    let title: String
    let trades: Int
    let totalR: Double
    let winRate: Double
}

struct MonthlyVerdict: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: BehaviorTone
}

struct MonthlyReport {
    var month: Date = .now
    var label = ""
    var tradesCount = 0
    var totalR = 0.0
    var wins = 0
    var losses = 0
    var breakEvens = 0
    var winRate = 0.0
    var profitFactor: Double?
    var expectancy = 0.0
    var avgWinR = 0.0
    var avgLossR = 0.0
    var avgPlannedRR = 0.0
    var tradingDays = 0
    var maxDrawdown = 0.0
    var bestDay: (date: Date, r: Double)?
    var worstDay: (date: Date, r: Double)?
    var bestTrade: Trade?
    var worstTrade: Trade?
    var longestTP = 0
    var longestSL = 0
    var currentStreakText = ""

    var scores: [MonthScore] = []
    var totalScore = 0
    var grade = "—"
    var edge: AlexEdgeState = .insufficient
    var verdicts: [MonthlyVerdict] = []
    var weeks: [MonthWeek] = []
    var structures: [MonthGroup] = []
    var sessions: [MonthGroup] = []
    var intraday: MonthGroup?
    var swing: MonthGroup?

    var planShare = 0.0
    var narrativeShare = 0.0
    var checklistShare = 0.0
    var reviewShare = 0.0
    var averageRiskUSD = 0.0
    var averageRiskPercent: Double?
    var overRiskCount = 0
    var ladderMismatch = 0
    var nextSteps: [String] = []
}

enum MonthlyPerformanceEngine {
    static func monthStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func report(
        month: Date,
        trades: [Trade],
        settings: AppSettings?,
        accounts: [TradingAccount]
    ) -> MonthlyReport {
        let calendar = Calendar.current
        let start = monthStart(month, calendar: calendar)
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return MonthlyReport(month: start, label: Fmt.monthYear(start))
        }

        let closed = trades
            .filter { $0.result != .open }
            .filter { date in
                let closeDate = date.closedAt ?? date.entryDate
                return closeDate >= start && closeDate < end
            }
            .sorted { ($0.closedAt ?? $0.entryDate) < ($1.closedAt ?? $1.entryDate) }

        var report = MonthlyReport(month: start, label: Fmt.monthYear(start))
        report.tradesCount = closed.count
        guard !closed.isEmpty else { return report }

        let values = closed.map(\.actualR)
        report.totalR = values.reduce(0, +)
        report.wins = values.filter { $0 > 0.05 }.count
        report.losses = values.filter { $0 < -0.05 }.count
        report.breakEvens = closed.count - report.wins - report.losses
        report.winRate = Double(report.wins) / Double(closed.count)
        report.expectancy = report.totalR / Double(closed.count)

        let grossWin = values.reduce(0) { $0 + max($1, 0) }
        let grossLoss = values.reduce(0) { $0 + max(-$1, 0) }
        report.profitFactor = grossLoss > 0.0001 ? grossWin / grossLoss : nil

        let winners = values.filter { $0 > 0.05 }
        let losers = values.filter { $0 < -0.05 }
        report.avgWinR = winners.isEmpty ? 0 : winners.reduce(0, +) / Double(winners.count)
        report.avgLossR = losers.isEmpty ? 0 : losers.reduce(0, +) / Double(losers.count)
        report.avgPlannedRR = closed.reduce(0) { $0 + $1.plannedRR } / Double(closed.count)

        // Дни
        let days = Dictionary(grouping: closed) { calendar.startOfDay(for: $0.closedAt ?? $0.entryDate) }
        report.tradingDays = days.count
        let dayTotals = days.map { day, list in
            (date: day, r: list.reduce(0) { $0 + $1.actualR })
        }
        report.bestDay = dayTotals.max { $0.r < $1.r }
        report.worstDay = dayTotals.min { $0.r < $1.r }

        report.bestTrade = closed.max { $0.actualR < $1.actualR }
        report.worstTrade = closed.min { $0.actualR < $1.actualR }

        // Просадка месяца
        var cumulative = 0.0
        var peak = 0.0
        for trade in closed {
            cumulative += trade.actualR
            peak = max(peak, cumulative)
            report.maxDrawdown = max(report.maxDrawdown, peak - cumulative)
        }

        // Серии
        var runTP = 0
        var runSL = 0
        for trade in closed {
            if trade.actualR > 0.05 {
                runTP += 1
                runSL = 0
                report.longestTP = max(report.longestTP, runTP)
            } else if trade.actualR < -0.05 {
                runSL += 1
                runTP = 0
                report.longestSL = max(report.longestSL, runSL)
            } else {
                runTP = 0
                runSL = 0
            }
        }

        if let last = closed.last {
            if last.actualR > 0.05 {
                let run = closed.reversed().prefix { $0.actualR > 0.05 }.count
                report.currentStreakText = "\(run) TP подряд"
            } else if last.actualR < -0.05 {
                let run = closed.reversed().prefix { $0.actualR < -0.05 }.count
                report.currentStreakText = "\(run) SL подряд"
            } else {
                report.currentStreakText = "BE"
            }
        }

        // Недели месяца
        var weekStart = startOfWeek(for: start, calendar: calendar)
        while weekStart < end {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            let sliceStart = max(weekStart, start)
            let sliceEnd = min(weekEnd, end)
            let slice = closed.filter {
                let date = $0.closedAt ?? $0.entryDate
                return date >= sliceStart && date < sliceEnd
            }
            let r = slice.reduce(0) { $0 + $1.actualR }
            let weekWins = slice.filter { $0.actualR > 0.05 }.count
            report.weeks.append(
                MonthWeek(
                    id: weekStart,
                    label: weekLabel(start: sliceStart, end: sliceEnd, calendar: calendar),
                    trades: slice.count,
                    totalR: r,
                    winRate: slice.isEmpty ? 0 : Double(weekWins) / Double(slice.count)
                )
            )
            weekStart = weekEnd
        }

        // Структура и сессии
        report.structures = groups(
            closed,
            key: { $0.structure?.rawValue ?? "Без метки" }
        )
        report.sessions = groups(
            closed,
            key: { $0.marketSession.rawValue }
        )

        // Intraday / swing
        let intraday = closed.filter { holdingHours($0) < 24 }
        let swing = closed.filter { holdingHours($0) >= 24 }
        report.intraday = group(id: "intraday", title: "Intraday", trades: intraday)
        report.swing = group(id: "swing", title: "Swing", trades: swing)

        // Процесс
        report.planShare = share(closed) { $0.plan != nil }
        report.checklistShare = share(closed) { $0.plan?.isChecklistComplete ?? false }
        report.narrativeShare = share(closed) {
            $0.cycle?.pointAPrice != nil && $0.cycle?.pointBPrice != nil
        }
        report.reviewShare = share(closed) { $0.review?.isFilled ?? false }

        // Риск
        let equityMap = equityByAccount(accounts)
        let totalEquity = equityMap.values.reduce(0, +)
        let maxRiskPercent = max(settings?.maxRiskPercent ?? 1, 0.1)
        report.averageRiskUSD = closed.reduce(0) { $0 + $1.riskUSD } / Double(closed.count)

        var percentValues: [Double] = []
        var overCount = 0
        var mismatches = 0
        let amounts = settings?.ladderAmounts ?? [12, 25, 50]

        for trade in closed {
            let denominator: Double?
            if let account = trade.account, let value = equityMap[account.persistentModelID], value > 0 {
                denominator = value
            } else if totalEquity > 0 {
                denominator = totalEquity
            } else {
                denominator = nil
            }

            if let denominator {
                let percent = trade.riskUSD / denominator * 100
                percentValues.append(percent)
                if percent > maxRiskPercent + 0.0001 {
                    overCount += 1
                }
            }

            let expected = amounts[min(max(trade.ladderStepIndex, 0), amounts.count - 1)]
            if abs(trade.riskUSD - expected) > 0.51 {
                mismatches += 1
            }
        }

        report.averageRiskPercent = percentValues.isEmpty
            ? nil
            : percentValues.reduce(0, +) / Double(percentValues.count)
        report.overRiskCount = overCount
        report.ladderMismatch = mismatches

        // Оценки
        let profitableWeeks = report.weeks.filter { $0.trades > 0 && $0.totalR > 0.05 }.count
        let activeWeeks = report.weeks.filter { $0.trades > 0 }.count
        let consistency = activeWeeks > 0 ? Double(profitableWeeks) / Double(activeWeeks) : 0
        let riskScore = max(0, 1 - Double(overCount + mismatches) / Double(closed.count))
        let processScore = (report.planShare + report.narrativeShare + report.reviewShare) / 3

        report.scores = [
            MonthScore(
                id: "pf",
                title: "Edge",
                detail: "Profit factor \(report.profitFactor.map { String(format: "%.2f", $0) } ?? "—")",
                value: min(max(((report.profitFactor ?? 0) - 0.8) / 1.7, 0), 1)
            ),
            MonthScore(
                id: "expectancy",
                title: "Ожидание",
                detail: "Средний результат \(AlgorithmMonitorEngine.signed(report.expectancy)) на сделку",
                value: min(max(report.expectancy / 0.6, 0), 1)
            ),
            MonthScore(
                id: "consistency",
                title: "Постоянство",
                detail: "\(profitableWeeks) из \(activeWeeks) прибыльных недель",
                value: consistency
            ),
            MonthScore(
                id: "risk",
                title: "Дисциплина риска",
                detail: "Превышений \(overCount) · не по ступени \(mismatches)",
                value: riskScore
            ),
            MonthScore(
                id: "process",
                title: "Процесс",
                detail: "План \(percentText(report.planShare)) · A→B \(percentText(report.narrativeShare)) · разбор \(percentText(report.reviewShare))",
                value: processScore
            )
        ]

        report.totalScore = report.scores.reduce(0) { $0 + $1.points }
        report.grade = grade(for: report.totalScore)

        report.edge = edgeState(for: report)
        report.verdicts = verdicts(for: report)
        report.nextSteps = nextSteps(for: report)
        return report
    }

    // MARK: - Разбор

    private static func edgeState(for report: MonthlyReport) -> AlexEdgeState {
        guard report.tradesCount >= 5 else { return .insufficient }
        let pf = report.profitFactor ?? 0
        if pf >= 1.5 && report.expectancy > 0.2 { return .working }
        if pf >= 1 && report.expectancy > 0 { return .fragile }
        return .broken
    }

    private static func verdicts(for report: MonthlyReport) -> [MonthlyVerdict] {
        var items: [MonthlyVerdict] = []

        items.append(
            MonthlyVerdict(
                id: "edge",
                title: report.edge.title,
                detail: report.edge.detail,
                tone: report.edge == .working ? .positive : (report.edge == .broken ? .negative : .neutral)
            )
        )

        let asymmetry = report.avgLossR != 0
            ? abs(report.avgWinR / report.avgLossR)
            : 0
        items.append(
            MonthlyVerdict(
                id: "asymmetry",
                title: "Асимметрия \(String(format: "%.2f", asymmetry))",
                detail: "Средний TP \(AlgorithmMonitorEngine.signed(report.avgWinR)), средний SL \(AlgorithmMonitorEngine.signed(report.avgLossR)). Плановый RR в среднем \(String(format: "%.2f", report.avgPlannedRR)).",
                tone: asymmetry >= 1.5 ? .positive : (asymmetry < 1 ? .negative : .neutral)
            )
        )

        items.append(
            MonthlyVerdict(
                id: "process",
                title: "Нарратив и процесс",
                detail: "План был у \(percentText(report.planShare)) сделок, чек-лист закрыт в \(percentText(report.checklistShare)), маршрут A→B зафиксирован в \(percentText(report.narrativeShare)), разбор заполнен у \(percentText(report.reviewShare)).",
                tone: report.narrativeShare >= 0.7 ? .positive : .neutral
            )
        )

        let profitableWeeks = report.weeks.filter { $0.trades > 0 && $0.totalR > 0.05 }.count
        let activeWeeks = report.weeks.filter { $0.trades > 0 }.count
        if activeWeeks > 0 {
            items.append(
                MonthlyVerdict(
                    id: "weeks",
                    title: "Постоянство",
                    detail: "\(profitableWeeks) из \(activeWeeks) недель закрыты в плюс. Лучшая неделя \(Fmt.r(report.weeks.map(\.totalR).max() ?? 0)), худшая \(Fmt.r(report.weeks.map(\.totalR).min() ?? 0)).",
                    tone: Double(profitableWeeks) / Double(activeWeeks) >= 0.6 ? .positive : .neutral
                )
            )
        }

        if report.overRiskCount > 0 || report.ladderMismatch > 0 {
            items.append(
                MonthlyVerdict(
                    id: "risk",
                    title: "Дисциплина риска",
                    detail: "\(report.overRiskCount) сделок выше лимита риска, \(report.ladderMismatch) — не по размеру ступени. Средний риск \(Fmt.money(report.averageRiskUSD))\(report.averageRiskPercent.map { ", \(percentText($0)) капитала" } ?? "").",
                    tone: .negative
                )
            )
        }

        if let best = report.structures.max(by: { $0.totalR < $1.totalR }), best.trades >= 2,
           let worst = report.structures.min(by: { $0.totalR < $1.totalR }), worst.trades >= 2,
           worst.totalR < -0.05 {
            items.append(
                MonthlyVerdict(
                    id: "structure",
                    title: "Setup ≠ edge",
                    detail: "\(best.title): \(Fmt.r(best.totalR)) на \(Fmt.deals(best.trades)). \(worst.title): \(Fmt.r(worst.totalR)) на \(Fmt.deals(worst.trades)). Разница между сетапами — это и есть качество контекста.",
                    tone: .neutral
                )
            )
        }

        if let session = report.sessions.filter({ $0.trades >= 2 }).min(by: { $0.totalR < $1.totalR }),
           session.totalR < -0.05 {
            items.append(
                MonthlyVerdict(
                    id: "session",
                    title: "Слабая сессия",
                    detail: "\(session.title): \(Fmt.r(session.totalR)) на \(Fmt.deals(session.trades)), win rate \(percentText(session.winRate)).",
                    tone: .negative
                )
            )
        }

        return Array(items.prefix(6))
    }

    private static func nextSteps(for report: MonthlyReport) -> [String] {
        var steps: [String] = []

        if report.planShare < 0.8 {
            steps.append("Довести долю сделок по плану до 80%: сейчас \(percentText(report.planShare)).")
        }
        if report.narrativeShare < 0.7 {
            steps.append("Фиксировать маршрут A→B в цикле до входа: сейчас \(percentText(report.narrativeShare)).")
        }
        if report.reviewShare < 0.8 {
            steps.append("Заполнять разбор каждой закрытой сделки: сейчас \(percentText(report.reviewShare)).")
        }
        if report.overRiskCount > 0 {
            steps.append("Не превышать \(percentText(report.averageRiskPercent ?? 1)) капитала на сделку — превышений было \(report.overRiskCount).")
        }
        if report.ladderMismatch > 0 {
            steps.append("Держать риск строго по размеру ступени — расхождений было \(report.ladderMismatch).")
        }
        if let worst = report.sessions.filter({ $0.trades >= 2 }).min(by: { $0.totalR < $1.totalR }),
           worst.totalR < -0.05 {
            steps.append("Ограничить входы в сессию «\(worst.title)» до подтверждённого сетапа: там \(Fmt.r(worst.totalR)).")
        }
        if report.edge == .broken {
            steps.append("Пересобрать тезис месяца: profit factor ниже 1 — сначала качество сетапа, потом количество входов.")
        }
        if steps.isEmpty {
            steps.append("Сохранять текущий процесс: план, нарратив, риск и разбор держатся на уровне. Следующий шаг — квартальная аналитика.")
        }
        return Array(steps.prefix(5))
    }

    // MARK: - Помощники

    static func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func grade(for score: Int) -> String {
        switch score {
        case 85...: return "A"
        case 70..<85: return "B"
        case 55..<70: return "C"
        default: return "D"
        }
    }

    private static func share(_ trades: [Trade], where predicate: (Trade) -> Bool) -> Double {
        guard !trades.isEmpty else { return 0 }
        return Double(trades.filter(predicate).count) / Double(trades.count)
    }

    private static func holdingHours(_ trade: Trade) -> Double {
        guard let closedAt = trade.closedAt else { return 0 }
        return closedAt.timeIntervalSince(trade.entryDate) / 3600
    }

    private static func groups(_ trades: [Trade], key: (Trade) -> String) -> [MonthGroup] {
        Dictionary(grouping: trades, by: key)
            .map { title, list in group(id: title, title: title, trades: list) }
            .sorted {
                if abs($0.totalR - $1.totalR) > 0.0001 { return $0.totalR > $1.totalR }
                return $0.trades > $1.trades
            }
    }

    private static func group(id: String, title: String, trades: [Trade]) -> MonthGroup {
        let wins = trades.filter { $0.actualR > 0.05 }.count
        return MonthGroup(
            id: id,
            title: title,
            trades: trades.count,
            totalR: trades.reduce(0) { $0 + $1.actualR },
            winRate: trades.isEmpty ? 0 : Double(wins) / Double(trades.count)
        )
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    private static func weekLabel(start: Date, end: Date, calendar: Calendar) -> String {
        let startDay = calendar.component(.day, from: start)
        let lastDay = Calendar.current.component(.day, from: calendar.date(byAdding: .day, value: -1, to: end) ?? end)
        return String(format: "%02d–%02d", startDay, lastDay)
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

    static func promptSummary(_ report: MonthlyReport) -> String {
        var lines: [String] = []
        lines.append(
            "Месяц: \(report.label). Сделок \(report.tradesCount), итог \(Fmt.r(report.totalR)), win rate \(percentText(report.winRate)), profit factor \(report.profitFactor.map { String(format: "%.2f", $0) } ?? "—"), expectancy \(AlgorithmMonitorEngine.signed(report.expectancy))."
        )
        lines.append(
            "Edge: \(report.edge.title). Оценка месяца \(report.totalScore)/100 (\(report.grade))."
        )
        lines.append(
            "Процесс: план \(percentText(report.planShare)), чек-лист \(percentText(report.checklistShare)), A→B \(percentText(report.narrativeShare)), разбор \(percentText(report.reviewShare))."
        )
        lines.append(
            "Риск: средний \(Fmt.money(report.averageRiskUSD))\(report.averageRiskPercent.map { ", \(percentText($0)) капитала" } ?? ""), превышений \(report.overRiskCount), не по ступени \(report.ladderMismatch)."
        )
        for verdict in report.verdicts {
            lines.append("\(verdict.title): \(verdict.detail)")
        }
        if !report.nextSteps.isEmpty {
            lines.append("План на следующий месяц: " + report.nextSteps.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }
}

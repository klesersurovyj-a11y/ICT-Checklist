//
//  AlgorithmMonitorEngine.swift
//  ICT Checklist
//
//  Algorithm Monitor: контроль эффективности алгоритма во времени.
//

import Foundation

/// Состояние алгоритма по последним сделкам.
enum AlgoHealth {
    case unknown
    case stable
    case watch
    case decline

    var title: String {
        switch self {
        case .unknown:
            return "Копится выборка"
        case .stable:
            return "Алгоритм стабилен"
        case .watch:
            return "Наблюдать"
        case .decline:
            return "Возможное ухудшение"
        }
    }

    var icon: String {
        switch self {
        case .unknown:
            return "hourglass"
        case .stable:
            return "checkmark.shield"
        case .watch:
            return "eye"
        case .decline:
            return "exclamationmark.triangle"
        }
    }
}

/// Окно сделок: последние 20, 40 или 100.
struct AlgoWindow {
    let size: Int
    let trades: [Trade]

    init(size: Int, trades: [Trade]) {
        self.size = size
        self.trades = trades
    }

    var count: Int { trades.count }

    private var values: [Double] { trades.map(\.actualR) }

    var wins: Int { values.filter { $0 > 0.05 }.count }
    var losses: Int { values.filter { $0 < -0.05 }.count }
    var breakEvens: Int { max(0, count - wins - losses) }
    var totalR: Double { values.reduce(0, +) }

    var winRate: Double {
        count > 0 ? Double(wins) / Double(count) : 0
    }

    var expectancy: Double {
        count > 0 ? totalR / Double(count) : 0
    }

    var profitFactor: Double? {
        let grossWin = values.reduce(0) { $0 + max($1, 0) }
        let grossLoss = values.reduce(0) { $0 + max(-$1, 0) }
        guard grossLoss > 0.0001 else { return nil }
        return grossWin / grossLoss
    }
}

/// Точка скользящего графика: значение метрики после каждой сделки.
struct AlgoPoint: Identifiable {
    let id: Int
    let date: Date
    let winRate: Double
    let expectancy: Double
    let profitFactor: Double?
}

struct AlgoStreak {
    enum Kind {
        case none
        case tp
        case sl
        case be
    }

    let kind: Kind
    let length: Int
    let totalR: Double

    var title: String {
        switch kind {
        case .none:
            return "Нет данных"
        case .tp:
            return "\(length) TP подряд"
        case .sl:
            return "\(length) SL подряд"
        case .be:
            return "Серия BE"
        }
    }
}

struct AlgoSignal: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: BehaviorTone
}

struct AlgoReport {
    var closedCount = 0
    var last20 = AlgoWindow(size: 20, trades: [])
    var last40 = AlgoWindow(size: 40, trades: [])
    var last100 = AlgoWindow(size: 100, trades: [])
    var previous20: AlgoWindow? = nil
    var points: [AlgoPoint] = []
    var currentStreak = AlgoStreak(kind: .none, length: 0, totalR: 0)
    var longestTP = 0
    var longestSL = 0
    var health: AlgoHealth = .unknown
    var signals: [AlgoSignal] = []
    var winRateDelta: Double? = nil
    var expectancyDelta: Double? = nil
    var profitFactorDelta: Double? = nil
}

enum AlgorithmMonitorEngine {
    static let rollingWindow = 20
    static let minimumTrades = 5

    static func report(trades: [Trade]) -> AlgoReport {
        let closed = trades
            .filter { $0.result != .open }
            .sorted { ($0.closedAt ?? $0.entryDate) < ($1.closedAt ?? $1.entryDate) }

        var result = AlgoReport()
        result.closedCount = closed.count
        result.last20 = AlgoWindow(size: 20, trades: Array(closed.suffix(20)))
        result.last40 = AlgoWindow(size: 40, trades: Array(closed.suffix(40)))
        result.last100 = AlgoWindow(size: 100, trades: Array(closed.suffix(100)))
        result.currentStreak = currentStreak(in: closed)

        let longest = longestStreaks(in: closed)
        result.longestTP = longest.tp
        result.longestSL = longest.sl

        guard closed.count >= minimumTrades else {
            result.signals = [
                AlgoSignal(
                    id: "sample",
                    title: "Мало данных",
                    detail: "Нужно хотя бы \(minimumTrades) закрытых сделок — сейчас \(closed.count). Скользящие метрики появятся автоматически.",
                    tone: .neutral
                )
            ]
            return result
        }

        result.points = rollingPoints(closed)

        if closed.count > 20 {
            let previous = AlgoWindow(size: 20, trades: Array(closed.dropLast(20).suffix(20)))
            if previous.count >= 10 {
                result.previous20 = previous
                result.winRateDelta = result.last20.winRate - previous.winRate
                result.expectancyDelta = result.last20.expectancy - previous.expectancy
                if let now = result.last20.profitFactor, let before = previous.profitFactor {
                    result.profitFactorDelta = now - before
                }
            }
        }

        guard closed.count >= 20 else {
            result.health = .unknown
            result.signals = [
                AlgoSignal(
                    id: "small-sample",
                    title: "Копится выборка",
                    detail: "\(closed.count) из 20 сделок: метрики уже считаются, но для сигнала нужно 20 — иначе выводы случайны.",
                    tone: .neutral
                )
            ]
            return result
        }

        let evaluation = evaluate(result)
        result.signals = evaluation.signals
        result.health = evaluation.health
        return result
    }

    // MARK: - Скользящие метрики

    private static func rollingPoints(_ closed: [Trade]) -> [AlgoPoint] {
        guard closed.count >= minimumTrades else { return [] }

        var points: [AlgoPoint] = []
        for index in (minimumTrades - 1)..<closed.count {
            let start = max(0, index - rollingWindow + 1)
            let slice = Array(closed[start...index])
            let window = AlgoWindow(size: rollingWindow, trades: slice)
            points.append(
                AlgoPoint(
                    id: index,
                    date: closed[index].closedAt ?? closed[index].entryDate,
                    winRate: window.winRate,
                    expectancy: window.expectancy,
                    profitFactor: window.profitFactor
                )
            )
        }
        return points
    }

    // MARK: - Серии

    private static func currentStreak(in closed: [Trade]) -> AlgoStreak {
        guard let last = closed.last else {
            return AlgoStreak(kind: .none, length: 0, totalR: 0)
        }

        let kind: AlgoStreak.Kind
        if last.actualR > 0.05 {
            kind = .tp
        } else if last.actualR < -0.05 {
            kind = .sl
        } else {
            return AlgoStreak(kind: .be, length: 1, totalR: last.actualR)
        }

        var length = 0
        var total = 0.0
        for trade in closed.reversed() {
            let matches: Bool
            switch kind {
            case .tp:
                matches = trade.actualR > 0.05
            case .sl:
                matches = trade.actualR < -0.05
            case .be:
                matches = abs(trade.actualR) <= 0.05
            case .none:
                matches = false
            }
            guard matches else { break }
            length += 1
            total += trade.actualR
        }

        return AlgoStreak(kind: kind, length: length, totalR: total)
    }

    private static func longestStreaks(in closed: [Trade]) -> (tp: Int, sl: Int) {
        var bestTP = 0
        var bestSL = 0
        var runTP = 0
        var runSL = 0

        for trade in closed {
            if trade.actualR > 0.05 {
                runTP += 1
                runSL = 0
                bestTP = max(bestTP, runTP)
            } else if trade.actualR < -0.05 {
                runSL += 1
                runTP = 0
                bestSL = max(bestSL, runSL)
            } else {
                runTP = 0
                runSL = 0
            }
        }

        return (bestTP, bestSL)
    }

    // MARK: - Сигналы

    private static func evaluate(_ report: AlgoReport) -> (signals: [AlgoSignal], health: AlgoHealth) {
        var signals: [AlgoSignal] = []
        var severity = 0

        func add(_ id: String, _ title: String, _ detail: String, _ tone: BehaviorTone, _ level: Int) {
            signals.append(AlgoSignal(id: id, title: title, detail: detail, tone: tone))
            severity = max(severity, level)
        }

        let last20 = report.last20
        let previous = report.previous20

        if let previous, previous.count >= 10 {
            let winDelta = last20.winRate - previous.winRate
            if winDelta <= -0.10 {
                add(
                    "winrate-drop",
                    "Win rate падает",
                    "Последние 20: \(percent(last20.winRate)) против \(percent(previous.winRate)) у предыдущих 20 — минус \(pointsText(winDelta)).",
                    .negative,
                    2
                )
            } else if winDelta <= -0.05 {
                add(
                    "winrate-watch",
                    "Win rate просел",
                    "Последние 20: \(percent(last20.winRate)) против \(percent(previous.winRate)) — минус \(pointsText(winDelta)). Следите за следующими входами.",
                    .neutral,
                    1
                )
            } else if winDelta >= 0.10 {
                add(
                    "winrate-up",
                    "Win rate растёт",
                    "Последние 20: \(percent(last20.winRate)) против \(percent(previous.winRate)) — плюс \(pointsText(winDelta)).",
                    .positive,
                    0
                )
            }

            let rDelta = last20.expectancy - previous.expectancy
            if rDelta <= -0.30 {
                add(
                    "expectancy-drop",
                    "Expectancy падает",
                    "Средний результат последних 20 — \(signed(last20.expectancy)), у предыдущих 20 — \(signed(previous.expectancy)).",
                    .negative,
                    2
                )
            } else if rDelta >= 0.30 {
                add(
                    "expectancy-up",
                    "Expectancy растёт",
                    "Средний результат последних 20 — \(signed(last20.expectancy)), у предыдущих 20 — \(signed(previous.expectancy)).",
                    .positive,
                    0
                )
            }

            if let now = last20.profitFactor, let before = previous.profitFactor,
               now < 1.0, before >= 1.0 {
                add(
                    "pf-below-one",
                    "Profit factor ниже 1",
                    "Последние 20: \(ratio(now)), предыдущие 20: \(ratio(before)). Система перестала зарабатывать на текущей выборке.",
                    .negative,
                    2
                )
            }
        }

        if last20.totalR < 0, report.last100.totalR > 0 {
            add(
                "recent-negative",
                "Последние 20 в минусе",
                "\(signed(last20.totalR)) за 20 сделок, хотя на 100 сделках \(signed(report.last100.totalR)). Похоже на смену условий рынка.",
                .negative,
                2
            )
        }

        let streak = report.currentStreak
        if streak.kind == .sl, streak.length >= 4 {
            add(
                "sl-streak",
                "Серия SL: \(streak.length)",
                "\(signed(streak.totalR)) за серию. Максимальная серия SL в базе — \(report.longestSL). Проверьте риск и качество сетапов.",
                .negative,
                2
            )
        } else if streak.kind == .sl, streak.length == 3 {
            add(
                "sl-streak-watch",
                "Три SL подряд",
                "\(signed(streak.totalR)) за серию. Максимум в базе — \(report.longestSL). Пока это в пределах истории, но вход стоит перепроверить.",
                .neutral,
                1
            )
        }

        if streak.kind == .tp, streak.length >= 4 {
            add(
                "tp-streak",
                "Серия TP: \(streak.length)",
                "\(signed(streak.totalR)) за серию. Максимум в базе — \(report.longestTP).",
                .positive,
                0
            )
        }

        if signals.isEmpty {
            let pfText = last20.profitFactor.map { ratio($0) } ?? "—"
            signals.append(
                AlgoSignal(
                    id: "stable",
                    title: "Ухудшения не видно",
                    detail: "Последние 20: win rate \(percent(last20.winRate)), expectancy \(signed(last20.expectancy)), profit factor \(pfText). Метрики держатся на уровне базы.",
                    tone: .positive
                )
            )
        }

        let health: AlgoHealth
        switch severity {
        case 2:
            health = .decline
        case 1:
            health = .watch
        default:
            health = .stable
        }

        return (Array(signals.prefix(5)), health)
    }

    // MARK: - Форматирование

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func pointsText(_ value: Double) -> String {
        "\(Int((abs(value) * 100).rounded())) п.п."
    }

    static func signed(_ value: Double) -> String {
        let sign = value > 0.005 ? "+" : (value < -0.005 ? "\u{2212}" : "")
        return sign + String(format: "%.2f", abs(value)) + "R"
    }

    static func ratio(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func profitFactorDeltaText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value > 0.005 ? "+" : (value < -0.005 ? "\u{2212}" : "")
        return sign + String(format: "%.2f", abs(value))
    }

    static func promptSummary(_ report: AlgoReport) -> String {
        var lines: [String] = []
        lines.append(
            "Закрытых сделок: \(report.closedCount). Состояние: \(report.health.title)."
        )
        lines.append(
            "Последние 20: win rate \(percent(report.last20.winRate)), expectancy \(signed(report.last20.expectancy)), profit factor \(report.last20.profitFactor.map(ratio) ?? "—"), итог \(signed(report.last20.totalR))."
        )
        lines.append(
            "Последние 40: win rate \(percent(report.last40.winRate)), expectancy \(signed(report.last40.expectancy)), итог \(signed(report.last40.totalR))."
        )
        lines.append(
            "Последние 100: win rate \(percent(report.last100.winRate)), expectancy \(signed(report.last100.expectancy)), итог \(signed(report.last100.totalR))."
        )
        lines.append("Текущая серия: \(report.currentStreak.title) (\(signed(report.currentStreak.totalR))). Максимум TP подряд — \(report.longestTP), SL подряд — \(report.longestSL).")
        for signal in report.signals {
            lines.append("\(signal.title): \(signal.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

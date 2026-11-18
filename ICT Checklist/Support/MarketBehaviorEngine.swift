//
//  MarketBehaviorEngine.swift
//  ICT Checklist
//
//  Поведение торговой системы по рыночной структуре, сессиям,
//  дням недели, инструментам и типам POI.
//

import Foundation

/// Период анализа: база целиком, последние 90 или 30 дней.
enum BehaviorPeriod: String, CaseIterable, Identifiable {
    case all = "Всё"
    case last90 = "90 дней"
    case last30 = "30 дней"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .all:
            return "Все закрытые сделки базы"
        case .last90:
            return "Закрытые за последние 90 дней"
        case .last30:
            return "Закрытые за последние 30 дней"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .last30, .last90:
            let days = self == .last30 ? 30 : 90
            guard let start = calendar.date(
                byAdding: .day,
                value: -days,
                to: calendar.startOfDay(for: .now)
            ) else {
                return true
            }
            return date >= start
        }
    }
}

/// Одна группа разбивки: метка и сделки, которые в неё попали.
struct BehaviorGroup: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    let trades: [Trade]
    var isUnlabeled: Bool = false

    var count: Int { trades.count }

    var wins: Int {
        trades.filter { $0.actualR > 0.05 }.count
    }

    var losses: Int {
        trades.filter { $0.actualR < -0.05 }.count
    }

    var breakEvens: Int {
        max(0, count - wins - losses)
    }

    var totalR: Double {
        trades.reduce(0) { $0 + $1.actualR }
    }

    var winRate: Double {
        count > 0 ? Double(wins) / Double(count) : 0
    }

    var averageR: Double {
        count > 0 ? totalR / Double(count) : 0
    }

    var profitFactor: Double? {
        let grossWin = trades.reduce(0) { $0 + max($1.actualR, 0) }
        let grossLoss = trades.reduce(0) { $0 + max(-$1.actualR, 0) }
        guard grossLoss > 0.0001 else { return nil }
        return grossWin / grossLoss
    }
}

/// Одно измерение анализа: например, «Структура рынка» и его группы.
struct BehaviorDimension: Identifiable {
    let id: String
    let title: String
    let caption: String
    let groups: [BehaviorGroup]

    var filledGroups: [BehaviorGroup] {
        groups.filter { $0.count > 0 }
    }

    /// Максимальный |R| среди групп — для длины полос.
    var maxMagnitude: Double {
        max(0.01, filledGroups.map { abs($0.totalR) }.max() ?? 0)
    }
}

enum BehaviorTone {
    case positive
    case negative
    case neutral
}

struct BehaviorInsight: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: BehaviorTone
}

struct BehaviorReport {
    var closedCount = 0
    var wins = 0
    var losses = 0
    var totalR: Double = 0
    var winRate: Double = 0
    var averageR: Double = 0
    var profitFactor: Double?
    var unlabeledStructure = 0
    var unlabeledPOI = 0
    var dimensions: [BehaviorDimension] = []
    var insights: [BehaviorInsight] = []
}

enum MarketBehaviorEngine {
    /// Минимальная выборка, при которой группа участвует в выводах.
    static let minimumSample = 3

    static func report(trades: [Trade], period: BehaviorPeriod) -> BehaviorReport {
        let calendar = Calendar.current
        let closed = trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.entryDate, calendar: calendar) }
            .sorted { ($0.closedAt ?? $0.entryDate) > ($1.closedAt ?? $1.entryDate) }

        var result = BehaviorReport()
        result.closedCount = closed.count
        guard !closed.isEmpty else { return result }

        result.wins = closed.filter { $0.actualR > 0.05 }.count
        result.losses = closed.filter { $0.actualR < -0.05 }.count
        result.totalR = closed.reduce(0) { $0 + $1.actualR }
        result.winRate = Double(result.wins) / Double(closed.count)
        result.averageR = result.totalR / Double(closed.count)
        result.profitFactor = profitFactor(of: closed)

        let unlabeledStructure = closed.filter { $0.structure == nil }
        let unlabeledPOI = closed.filter { $0.poiType == nil }
        result.unlabeledStructure = unlabeledStructure.count
        result.unlabeledPOI = unlabeledPOI.count

        let structureGroups = MarketStructure.allCases.map { value in
            BehaviorGroup(
                id: "structure-\(value.rawValue)",
                title: value.rawValue,
                subtitle: value.subtitle,
                trades: closed.filter { $0.structure == value }
            )
        } + unlabeledGroup(
            unlabeledStructure,
            id: "structure-none",
            title: "Без метки структуры",
            subtitle: "Разметьте сделку в её карточке"
        )

        let sessionGroups = MarketSession.allCases.map { value in
            BehaviorGroup(
                id: "session-\(value.rawValue)",
                title: value.rawValue,
                subtitle: value.timeRange,
                trades: closed.filter { $0.marketSession == value }
            )
        }

        let weekdayGroups = (0..<StatsEngine.weekdayTitles.count).map { index in
            BehaviorGroup(
                id: "weekday-\(index)",
                title: StatsEngine.weekdayTitles[index],
                subtitle: StatsEngine.weekdayNames[index],
                trades: closed.filter { StatsEngine.weekdayIndex(for: $0) == index }
            )
        }

        let symbolGroups = Dictionary(grouping: closed, by: { $0.symbol })
            .map { symbol, items in
                BehaviorGroup(id: "symbol-\(symbol)", title: symbol, trades: items)
            }
            .sorted { first, second in
                if abs(first.totalR - second.totalR) > 0.0001 { return first.totalR > second.totalR }
                if first.count != second.count { return first.count > second.count }
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }

        let poiGroups = POIType.allCases.map { value in
            BehaviorGroup(
                id: "poi-\(value.rawValue)",
                title: value.rawValue,
                subtitle: value.subtitle,
                trades: closed.filter { $0.poiType == value }
            )
        } + unlabeledGroup(
            unlabeledPOI,
            id: "poi-none",
            title: "Без POI",
            subtitle: "Укажите POI в карточке сделки"
        )

        result.dimensions = [
            BehaviorDimension(
                id: "structure",
                title: "Trend · Reversal · Correction",
                caption: "Результат по рыночной структуре",
                groups: structureGroups
            ),
            BehaviorDimension(
                id: "session",
                title: "Сессии",
                caption: "Результат по торговым сессиям",
                groups: sessionGroups
            ),
            BehaviorDimension(
                id: "weekday",
                title: "Дни недели",
                caption: "Результат по дням недели",
                groups: weekdayGroups
            ),
            BehaviorDimension(
                id: "symbol",
                title: "Инструменты",
                caption: "Результат по торговым инструментам",
                groups: symbolGroups
            ),
            BehaviorDimension(
                id: "poi",
                title: "Типы POI",
                caption: "Результат по точкам интереса",
                groups: poiGroups
            )
        ]

        result.insights = insights(for: result)
        return result
    }

    // MARK: - Группы

    private static func unlabeledGroup(
        _ trades: [Trade],
        id: String,
        title: String,
        subtitle: String
    ) -> [BehaviorGroup] {
        guard !trades.isEmpty else { return [] }
        return [
            BehaviorGroup(
                id: id,
                title: title,
                subtitle: subtitle,
                trades: trades,
                isUnlabeled: true
            )
        ]
    }

    // MARK: - Выводы

    /// Группа с лучшим средним результатом на сделку.
    static func bestGroup(
        _ dimension: BehaviorDimension?,
        minimum: Int = minimumSample
    ) -> BehaviorGroup? {
        guard let dimension else { return nil }
        return dimension.groups
            .filter { $0.count >= minimum && !$0.isUnlabeled }
            .max { $0.averageR < $1.averageR }
    }

    /// Группа с худшим средним результатом на сделку.
    static func worstGroup(
        _ dimension: BehaviorDimension?,
        minimum: Int = minimumSample
    ) -> BehaviorGroup? {
        guard let dimension else { return nil }
        return dimension.groups
            .filter { $0.count >= minimum && !$0.isUnlabeled }
            .min { $0.averageR < $1.averageR }
    }

    private static func weakestWinRate(_ dimension: BehaviorDimension?) -> BehaviorGroup? {
        guard let dimension else { return nil }
        let candidates = dimension.groups.filter { $0.count >= minimumSample && !$0.isUnlabeled }
        guard let group = candidates.min(by: { $0.winRate < $1.winRate }) else { return nil }
        return group.winRate < 0.4 ? group : nil
    }

    private static func insights(for report: BehaviorReport) -> [BehaviorInsight] {
        var items: [BehaviorInsight] = []

        guard report.closedCount >= 5 else {
            items.append(
                BehaviorInsight(
                    id: "sample",
                    title: "Мало данных",
                    detail: "\(Fmt.deals(report.closedCount)) за период — выводы по структуре пока преждевременны. Закрывайте сделки в цикле, чтобы база росла.",
                    tone: .neutral
                )
            )
            return items
        }

        let structure = report.dimensions.first { $0.id == "structure" }
        let session = report.dimensions.first { $0.id == "session" }
        let weekday = report.dimensions.first { $0.id == "weekday" }
        let symbol = report.dimensions.first { $0.id == "symbol" }
        let poi = report.dimensions.first { $0.id == "poi" }

        if let best = bestGroup(structure) {
            items.append(
                BehaviorInsight(
                    id: "best-structure",
                    title: "Сильнее всего — \(best.title)",
                    detail: "\(Fmt.r(best.totalR)) на \(Fmt.deals(best.count)), средний \(averageText(best.averageR)) на сделку, win rate \(percentText(best.winRate)).",
                    tone: .positive
                )
            )
        }

        if let worst = worstGroup(session), worst.averageR < -0.05 {
            items.append(
                BehaviorInsight(
                    id: "worst-session",
                    title: "Слабая сессия — \(worst.title)",
                    detail: "\(Fmt.r(worst.totalR)) на \(Fmt.deals(worst.count)), средний \(averageText(worst.averageR)). \(worst.subtitle ?? "") — проверьте, нужны ли там входы.",
                    tone: .negative
                )
            )
        }

        if let weakPOI = weakestWinRate(poi) {
            items.append(
                BehaviorInsight(
                    id: "weak-poi",
                    title: "POI с низким win rate — \(weakPOI.title)",
                    detail: "\(percentText(weakPOI.winRate)) прибыльных на \(Fmt.deals(weakPOI.count)), итог \(Fmt.r(weakPOI.totalR)). Сузьте требования к этой зоне.",
                    tone: .negative
                )
            )
        }

        if let bestSymbol = bestGroup(symbol), bestSymbol.averageR > 0.05 {
            items.append(
                BehaviorInsight(
                    id: "best-symbol",
                    title: "Лучший инструмент — \(bestSymbol.title)",
                    detail: "\(Fmt.r(bestSymbol.totalR)) на \(Fmt.deals(bestSymbol.count)), средний \(averageText(bestSymbol.averageR)). Здесь система работает как задумано.",
                    tone: .positive
                )
            )
        }

        if let worstDay = worstGroup(weekday), worstDay.averageR < -0.05 {
            items.append(
                BehaviorInsight(
                    id: "worst-weekday",
                    title: "Худший день — \(worstDay.subtitle ?? worstDay.title)",
                    detail: "\(Fmt.r(worstDay.totalR)) на \(Fmt.deals(worstDay.count)), средний \(averageText(worstDay.averageR)). Стоит проверить дисциплину и качество сетапов.",
                    tone: .negative
                )
            )
        }

        if report.unlabeledStructure > 0 || report.unlabeledPOI > 0 {
            items.append(
                BehaviorInsight(
                    id: "unlabeled",
                    title: "Не вся база размечена",
                    detail: "\(report.unlabeledStructure) без структуры, \(report.unlabeledPOI) без POI. Откройте сделку → «Поведение рынка» и поставьте метку.",
                    tone: .neutral
                )
            )
        }

        return Array(items.prefix(5))
    }

    // MARK: - Форматирование

    static func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func averageText(_ value: Double) -> String {
        let magnitude = abs(value)
        let sign = value > 0.005 ? "+" : (value < -0.005 ? "\u{2212}" : "")
        return sign + String(format: "%.2f", magnitude) + "R"
    }

    static func profitFactorText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func promptSummary(_ report: BehaviorReport, period: BehaviorPeriod) -> String {
        var lines: [String] = []
        lines.append(
            "Период: \(period.rawValue). Закрытых сделок: \(report.closedCount). Суммарно \(String(format: "%.2f", report.totalR))R, win rate \(percentText(report.winRate)), средний результат \(averageText(report.averageR))."
        )

        for dimension in report.dimensions {
            let parts = dimension.filledGroups.prefix(6).map { group in
                "\(group.title): \(group.count) сд., \(String(format: "%.2f", group.totalR))R, win \(percentText(group.winRate))"
            }
            if !parts.isEmpty {
                lines.append("\(dimension.title): " + parts.joined(separator: "; "))
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Помощники

    private static func profitFactor(of trades: [Trade]) -> Double? {
        let grossWin = trades.reduce(0) { $0 + max($1.actualR, 0) }
        let grossLoss = trades.reduce(0) { $0 + max(-$1.actualR, 0) }
        guard grossLoss > 0.0001 else { return nil }
        return grossWin / grossLoss
    }
}

//
//  StatsEngine.swift
//  ICT Checklist
//

import Foundation
import SwiftData

enum StatsPeriod: String, CaseIterable, Identifiable {
    case today = "Сегодня"
    case week = "Неделя"
    case all = "Всё"

    var id: String { rawValue }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .week:
            let start = calendar.startOfDay(for: .now)
            guard let weekStart = calendar.date(byAdding: .day, value: -6, to: start) else {
                return true
            }
            return date >= weekStart
        }
    }
}

struct StatsStreak {
    var count: Int = 0
    var totalR: Double = 0
}

struct StatsGroup: Identifiable {
    let id: String
    let title: String
    let count: Int
    let wins: Int
    let losses: Int
    let beCount: Int
    let totalR: Double
    /// Для разбивки по счетам — счёт, к которому относится группа.
    var kind: BreakdownKind? = nil

    var winRate: Double {
        guard count > 0 else { return 0 }
        return Double(wins) / Double(count)
    }
}

struct StatsSummary {
    var totalCount: Int = 0
    var closedCount: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var totalR: Double = 0
    var averageR: Double = 0
    var profitFactor: Double?
    var winRate: Double = 0
    var bestStreak = StatsStreak()
    var worstStreak = StatsStreak()
    var bySymbol: [StatsGroup] = []
    var byDirection: [StatsGroup] = []
    var byStep: [StatsGroup] = []
    var byWeekday: [StatsGroup] = []
    var byHour: [StatsGroup] = []
    var byTag: [StatsGroup] = []
}

struct ChartPoint: Identifiable {
    let id: Int
    let date: Date
    let value: Double
    let isStart: Bool
}

struct ChartSeries {
    var rPoints: [ChartPoint] = []
    var riskPoints: [ChartPoint] = []
    var finalR: Double = 0
}

enum BreakdownKind: Hashable {
    case symbol(String)
    case direction(Direction)
    case step(Int)
    /// 0 — понедельник … 6 — воскресенье.
    case weekday(Int)
    /// Час входа в сделку: 19 — 19:00 … 20 — 20:00.
    case hour(Int)
    case tag(String)
    /// Неделя: начало недели (понедельник), диапазон считается внутри.
    case week(Date)
    /// Сделки торгового счёта.
    case account(PersistentIdentifier)
    /// Сделки, не привязанные ни к одному счёту.
    case noAccount

    func matches(_ trade: Trade) -> Bool {
        switch self {
        case .symbol(let value):
            return trade.symbol == value
        case .direction(let value):
            return trade.direction == value
        case .step(let value):
            return trade.ladderStepIndex == value
        case .weekday(let value):
            return StatsEngine.weekdayIndex(for: trade) == value
        case .hour(let value):
            return StatsEngine.entryHour(for: trade) == value
        case .tag(let value):
            return trade.tags.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
        case .week(let start):
            guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else {
                return false
            }
            let day = Calendar.current.startOfDay(for: trade.tradingDay)
            return day >= start && day < end
        case .account(let id):
            return trade.account?.persistentModelID == id
        case .noAccount:
            return trade.account == nil
        }
    }

    /// Диапазон недели сам задаёт период, поэтому фильтр «Сегодня / Неделя / Всё» не нужен.
    var hasOwnRange: Bool {
        if case .week = self { return true }
        return false
    }
}

enum StatsEngine {
    /// Сводка по планам торговых дней.
    struct PlanStats {
        var total: Int = 0
        var decided: Int = 0
        var skipped: Int = 0
        var noTrade: Int = 0
        var pending: Int = 0
        var withResult: Int = 0
        var compliant: Int = 0

        var executionRate: Double {
            withResult > 0 ? Double(decided) / Double(withResult) : 0
        }

        var complianceRate: Double {
            decided > 0 ? Double(compliant) / Double(decided) : 0
        }
    }

    static func planStats(plans: [TradePlan], period: StatsPeriod) -> PlanStats {
        var stats = PlanStats()
        let calendar = Calendar.current
        let filtered = plans.filter { period.contains($0.day, calendar: calendar) }

        stats.total = filtered.count
        for plan in filtered {
            switch plan.result {
            case .win, .loss, .be:
                stats.decided += 1
                if plan.isChecklistComplete {
                    stats.compliant += 1
                }
            case .skip:
                stats.skipped += 1
            case .noTrade:
                stats.noTrade += 1
            case .pending:
                stats.pending += 1
            }
        }
        stats.withResult = stats.decided + stats.skipped + stats.noTrade
        return stats
    }

    /// Short names of the weekdays, Monday first.
    static let weekdayTitles = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
    /// Full names of the weekdays, Monday first.
    static let weekdayNames = [
        "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"
    ]

    /// 0 — понедельник … 6 — воскресенье.
    static func weekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        // Calendar считает дни недели от воскресенья.
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    static func weekdayIndex(for trade: Trade, calendar: Calendar = .current) -> Int {
        weekdayIndex(for: closeDate(trade), calendar: calendar)
    }

    /// Час, в который была открыта сделка.
    static func entryHour(for trade: Trade, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: trade.entryDate)
    }

    static func summary(trades: [Trade], amounts: [Double], period: StatsPeriod) -> StatsSummary {
        var result = StatsSummary()
        let calendar = Calendar.current

        result.totalCount = trades.filter { period.contains($0.entryDate, calendar: calendar) }.count

        let closed = trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.entryDate, calendar: calendar) }
            .sorted { closeDate($0) < closeDate($1) }

        result.closedCount = closed.count
        guard !closed.isEmpty else {
            result.byDirection = directionGroups(from: closed)
            result.byStep = stepGroups(from: closed, amounts: amounts)
            result.byWeekday = weekdayGroups(from: closed)
            result.byHour = hourGroups(from: closed)
            return result
        }

        var wins = 0
        var losses = 0
        var grossWin = 0.0
        var grossLoss = 0.0
        var total = 0.0
        var winRun = 0
        var lossRun = 0
        var winRunR = 0.0
        var lossRunR = 0.0

        for trade in closed {
            let r = trade.actualR
            total += r

            if r > 0.05 {
                wins += 1
                grossWin += r
                winRun += 1
                winRunR += r
                lossRun = 0
                lossRunR = 0
                if winRun > result.bestStreak.count
                    || (winRun == result.bestStreak.count && winRunR > result.bestStreak.totalR) {
                    result.bestStreak = StatsStreak(count: winRun, totalR: winRunR)
                }
            } else if r < -0.05 {
                losses += 1
                grossLoss += abs(r)
                lossRun += 1
                lossRunR += r
                winRun = 0
                winRunR = 0
                if lossRun > result.worstStreak.count
                    || (lossRun == result.worstStreak.count && lossRunR < result.worstStreak.totalR) {
                    result.worstStreak = StatsStreak(count: lossRun, totalR: lossRunR)
                }
            } else {
                // BE breaks a streak without counting as a win or a loss.
                winRun = 0
                winRunR = 0
                lossRun = 0
                lossRunR = 0
            }
        }

        result.wins = wins
        result.losses = losses
        result.totalR = total
        result.averageR = total / Double(closed.count)
        result.winRate = Double(wins) / Double(closed.count)
        if grossLoss > 0 {
            result.profitFactor = grossWin / grossLoss
        }

        result.bySymbol = symbolGroups(from: closed)
        result.byDirection = directionGroups(from: closed)
        result.byStep = stepGroups(from: closed, amounts: amounts)
        result.byWeekday = weekdayGroups(from: closed)
        result.byHour = hourGroups(from: closed)
        result.byTag = tagGroups(from: closed)

        return result
    }

    // MARK: - Charts

    static func charts(trades: [Trade], period: StatsPeriod) -> ChartSeries {
        let closed = trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.entryDate) }
            .sorted { closeDate($0) < closeDate($1) }

        guard let first = closed.first else { return ChartSeries() }

        var series = ChartSeries()
        series.rPoints.append(ChartPoint(id: -1, date: closeDate(first), value: 0, isStart: true))

        var cumulative = 0.0
        for (index, trade) in closed.enumerated() {
            cumulative += trade.actualR
            let date = closeDate(trade)
            series.rPoints.append(ChartPoint(id: index, date: date, value: cumulative, isStart: false))
            series.riskPoints.append(ChartPoint(id: index, date: date, value: trade.riskUSD, isStart: false))
        }
        series.finalR = cumulative
        return series
    }

    // MARK: - Breakdown details

    static func detailTrades(_ trades: [Trade], period: StatsPeriod, kind: BreakdownKind) -> [Trade] {
        let closed = trades.filter { $0.result != .open }
        let scoped = kind.hasOwnRange
            ? closed
            : closed.filter { period.contains($0.closedAt ?? $0.entryDate) }

        return scoped
            .filter { kind.matches($0) }
            .sorted { closeDate($0) > closeDate($1) }
    }

    // MARK: - Groups

    /// Разбивка по торговым счетам за выбранный период: счета без закрытых
    /// сделок не показываются, сделки без счёта собираются в «Без счёта».
    static func accountGroups(
        trades: [Trade],
        accounts: [TradingAccount],
        period: StatsPeriod
    ) -> [StatsGroup] {
        let calendar = Calendar.current
        let closed = trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.entryDate, calendar: calendar) }

        guard !closed.isEmpty else { return [] }

        var groups: [StatsGroup] = []

        for account in accounts {
            let items = closed.filter { $0.account?.persistentModelID == account.persistentModelID }
            guard !items.isEmpty else { continue }

            var group = makeGroup(
                id: "account-\(account.persistentModelID)",
                title: account.name.isEmpty ? "Счёт без названия" : account.name,
                trades: items
            )
            group.kind = .account(account.persistentModelID)
            groups.append(group)
        }

        let withoutAccount = closed.filter { $0.account == nil }
        if !withoutAccount.isEmpty {
            var group = makeGroup(id: "account-none", title: "Без счёта", trades: withoutAccount)
            group.kind = .noAccount
            groups.append(group)
        }

        return groups.sorted { first, second in
            if first.count != second.count { return first.count > second.count }
            if abs(first.totalR - second.totalR) > 0.0001 { return first.totalR > second.totalR }
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }

    private static func symbolGroups(from trades: [Trade]) -> [StatsGroup] {
        let grouped = Dictionary(grouping: trades) { $0.symbol }
        return grouped
            .map { symbol, items in
                makeGroup(id: "symbol-\(symbol)", title: symbol, trades: items)
            }
            .sorted { first, second in
                if first.count != second.count { return first.count > second.count }
                if abs(first.totalR - second.totalR) > 0.0001 { return first.totalR > second.totalR }
                return first.title < second.title
            }
    }

    private static func directionGroups(from trades: [Trade]) -> [StatsGroup] {
        Direction.allCases.map { direction in
            let items = trades.filter { $0.direction == direction }
            return makeGroup(id: "direction-\(direction.rawValue)", title: direction.rawValue, trades: items)
        }
    }

    private static func stepGroups(from trades: [Trade], amounts: [Double]) -> [StatsGroup] {
        (0..<3).map { index in
            let items = trades.filter { $0.ladderStepIndex == index }
            let amount = index < amounts.count ? amounts[index] : 0
            return makeGroup(id: "step-\(index)", title: Fmt.money(amount), trades: items)
        }
    }

    private static func weekdayGroups(from trades: [Trade]) -> [StatsGroup] {
        (0..<weekdayTitles.count).map { index in
            let items = trades.filter { weekdayIndex(for: $0) == index }
            return makeGroup(id: "weekday-\(index)", title: weekdayTitles[index], trades: items)
        }
    }

    private static func hourGroups(from trades: [Trade]) -> [StatsGroup] {
        let hours = Set(trades.map { entryHour(for: $0) }).sorted()
        return hours.map { hour in
            let items = trades.filter { entryHour(for: $0) == hour }
            return makeGroup(id: "hour-\(hour)", title: Fmt.clock(hour: hour, minute: 0), trades: items)
        }
    }

    private static func tagGroups(from trades: [Trade]) -> [StatsGroup] {
        var map: [String: [Trade]] = [:]
        for trade in trades {
            for tag in Set(trade.tags) {
                map[tag, default: []].append(trade)
            }
        }
        return map
            .map { tag, items in
                makeGroup(id: "tag-\(tag)", title: tag, trades: items)
            }
            .sorted { first, second in
                if first.count != second.count { return first.count > second.count }
                if abs(first.totalR - second.totalR) > 0.0001 { return first.totalR > second.totalR }
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
    }

    private static func makeGroup(id: String, title: String, trades: [Trade]) -> StatsGroup {
        var wins = 0
        var losses = 0
        var be = 0
        var total = 0.0

        for trade in trades {
            let r = trade.actualR
            total += r
            if r > 0.05 {
                wins += 1
            } else if r < -0.05 {
                losses += 1
            } else {
                be += 1
            }
        }

        return StatsGroup(
            id: id,
            title: title,
            count: trades.count,
            wins: wins,
            losses: losses,
            beCount: be,
            totalR: total
        )
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

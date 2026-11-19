//
//  MandateCompliance.swift
//  ICT Checklist
//
//  Проверка каждой сделки против активной версии мандата.
//

import Foundation
import SwiftData

enum MandateLimit: String, CaseIterable, Identifiable {
    case riskPerTrade = "Риск на сделку"
    case tradesPerDay = "Сделок в день"
    case dayRisk = "Риск дня"
    case monthRisk = "Риск месяца"
    case instrument = "Инструмент"
    case group = "Группа инструментов"
    case factor = "Фактор"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .riskPerTrade: return "Риск"
        case .tradesPerDay: return "Сделки дня"
        case .dayRisk: return "День"
        case .monthRisk: return "Месяц"
        case .instrument: return "Инструмент"
        case .group: return "Группа"
        case .factor: return "Фактор"
        }
    }
}

struct ComplianceViolation: Identifiable {
    let id: String
    let limit: MandateLimit
    let date: Date
    let symbol: String
    let detail: String
    let r: Double
    let trade: Trade?
}

struct MandateUsageRow: Identifiable {
    let limit: MandateLimit
    let used: Double
    let cap: Double
    let isPercent: Bool
    let exceeded: Bool

    var id: String { limit.id }

    var ratio: Double {
        guard cap > 0.01 else { return 0 }
        return used / cap
    }

    var excessText: String {
        let excess = used - cap
        guard excess > 0.001 else { return "в норме" }
        if isPercent {
            return String(format: "превышено на %.1f%%", excess)
        }
        return "превышено на \(Int(excess.rounded()))"
    }

    var valueText: String {
        if isPercent {
            return String(format: "%.1f%% из %.1f%%", used, cap)
        }
        return "\(Int(used.rounded())) из \(Int(cap.rounded()))"
    }
}

struct ComplianceReport {
    var hasMandate = false
    var version = 0
    var mandateDate: Date?
    var violations: [ComplianceViolation] = []
    var rows: [MandateUsageRow] = []
    var totalR = 0.0

    func violations(for limit: MandateLimit?) -> [ComplianceViolation] {
        guard let limit else { return violations }
        return violations.filter { $0.limit == limit }
    }
}

enum MandateCompliance {
    static func report(
        trades: [Trade],
        accounts: [TradingAccount],
        mandates: [FundMandate],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ComplianceReport {
        var report = ComplianceReport()

        guard let mandate = FundMandate.active(in: mandates) else { return report }
        report.hasMandate = true
        report.version = mandate.version
        report.mandateDate = mandate.createdAt

        let capital = accounts
            .filter { !$0.isArchived }
            .reduce(0) { $0 + $1.equity }
        guard capital > 0.01 else { return report }

        let open = trades.filter { $0.result == .open }
        let closed = trades.filter { $0.result != .open }

        var violations: [ComplianceViolation] = []

        // Риск на сделку.
        var maxTradeRisk = 0.0
        for trade in trades {
            let share = trade.riskUSD / capital * 100
            maxTradeRisk = max(maxTradeRisk, share)
            if share > mandate.riskPerTradePercent + 0.001 {
                violations.append(
                    ComplianceViolation(
                        id: "risk-\(trade.persistentModelID.hashValue)",
                        limit: .riskPerTrade,
                        date: trade.entryDate,
                        symbol: trade.symbol.uppercased(),
                        detail: "Риск \(String(format: "%.1f%%", share)) из \(String(format: "%.1f%%", mandate.riskPerTradePercent))",
                        r: trade.actualR,
                        trade: trade
                    )
                )
            }
        }

        // Сделки дня и потеря дня, потеря месяца.
        let byDay = Dictionary(grouping: trades, by: { calendar.startOfDay(for: $0.tradingDay) })
        var maxDayCount = 0
        var maxDayLoss = 0.0
        for (day, list) in byDay {
            maxDayCount = max(maxDayCount, list.count)
            let dayR = list.filter { $0.result != .open }.reduce(0) { $0 + $1.actualR }
            let dayMoney = list.filter { $0.result != .open }.reduce(0) { $0 + $1.riskUSD * $1.actualR }
            let dayLoss = dayMoney < 0 ? -dayMoney / capital * 100 : 0
            maxDayLoss = max(maxDayLoss, dayLoss)

            if list.count > mandate.maxTradesPerDay {
                violations.append(
                    ComplianceViolation(
                        id: "trades-\(day.timeIntervalSince1970)",
                        limit: .tradesPerDay,
                        date: day,
                        symbol: "—",
                        detail: "\(list.count) из \(mandate.maxTradesPerDay)",
                        r: dayR,
                        trade: nil
                    )
                )
            }

            if dayLoss > mandate.riskPerDayPercent + 0.001 {
                violations.append(
                    ComplianceViolation(
                        id: "day-\(day.timeIntervalSince1970)",
                        limit: .dayRisk,
                        date: day,
                        symbol: "—",
                        detail: "\(String(format: "%.1f%%", dayLoss)) из \(String(format: "%.1f%%", mandate.riskPerDayPercent))",
                        r: dayR,
                        trade: nil
                    )
                )
            }
        }

        let byMonth = Dictionary(grouping: closed, by: { monthStart($0.tradingDay, calendar) })
        var maxMonthLoss = 0.0
        for (month, list) in byMonth {
            let monthMoney = list.reduce(0) { $0 + $1.riskUSD * $1.actualR }
            let monthLoss = monthMoney < 0 ? -monthMoney / capital * 100 : 0
            maxMonthLoss = max(maxMonthLoss, monthLoss)
            guard monthLoss > mandate.riskPerMonthPercent + 0.001 else { continue }
            violations.append(
                ComplianceViolation(
                    id: "month-\(month.timeIntervalSince1970)",
                    limit: .monthRisk,
                    date: month,
                    symbol: "—",
                    detail: "\(String(format: "%.1f%%", monthLoss)) из \(String(format: "%.1f%%", mandate.riskPerMonthPercent))",
                    r: list.reduce(0) { $0 + $1.actualR },
                    trade: nil
                )
            )
        }

        // Открытый риск по инструменту, группе и фактору.
        var bySymbol: [String: Double] = [:]
        var byGroup: [String: Double] = [:]
        var byFactor: [String: Double] = [:]
        for trade in open {
            let symbol = trade.symbol.uppercased()
            bySymbol[symbol, default: 0] += trade.riskUSD
            byGroup[clusterKey(symbol), default: 0] += trade.riskUSD
            byFactor[factorKey(symbol, trade.direction), default: 0] += trade.riskUSD
        }

        let closedBySymbol = Dictionary(grouping: closed, by: { $0.symbol.uppercased() })
        let closedByGroup = Dictionary(grouping: closed, by: { clusterKey($0.symbol.uppercased()) })
        let closedByFactor = Dictionary(grouping: closed, by: { factorKey($0.symbol.uppercased(), $0.direction) })

        var maxInstrument = 0.0
        for (symbol, risk) in bySymbol {
            let share = risk / capital * 100
            maxInstrument = max(maxInstrument, share)
            guard share > mandate.maxInstrumentPercent + 0.001 else { continue }
            violations.append(
                ComplianceViolation(
                    id: "instrument-\(symbol)",
                    limit: .instrument,
                    date: now,
                    symbol: symbol,
                    detail: "\(String(format: "%.1f%%", share)) из \(String(format: "%.1f%%", mandate.maxInstrumentPercent))",
                    r: closedBySymbol[symbol]?.reduce(0) { $0 + $1.actualR } ?? 0,
                    trade: open.last { $0.symbol.uppercased() == symbol }
                )
            )
        }

        var maxGroup = 0.0
        for (group, risk) in byGroup {
            let share = risk / capital * 100
            maxGroup = max(maxGroup, share)
            guard share > mandate.maxGroupPercent + 0.001 else { continue }
            violations.append(
                ComplianceViolation(
                    id: "group-\(group)",
                    limit: .group,
                    date: now,
                    symbol: group,
                    detail: "\(String(format: "%.1f%%", share)) из \(String(format: "%.1f%%", mandate.maxGroupPercent))",
                    r: closedByGroup[group]?.reduce(0) { $0 + $1.actualR } ?? 0,
                    trade: nil
                )
            )
        }

        var maxFactor = 0.0
        for (factor, risk) in byFactor {
            let share = risk / capital * 100
            maxFactor = max(maxFactor, share)
            guard share > mandate.maxFactorPercent + 0.001 else { continue }
            violations.append(
                ComplianceViolation(
                    id: "factor-\(factor)",
                    limit: .factor,
                    date: now,
                    symbol: factor,
                    detail: "\(String(format: "%.1f%%", share)) из \(String(format: "%.1f%%", mandate.maxFactorPercent))",
                    r: closedByFactor[factor]?.reduce(0) { $0 + $1.actualR } ?? 0,
                    trade: nil
                )
            )
        }

        report.violations = violations.sorted { $0.date > $1.date }
        report.totalR = violations.reduce(0) { $0 + $1.r }

        report.rows = [
            MandateUsageRow(
                limit: .riskPerTrade,
                used: maxTradeRisk,
                cap: mandate.riskPerTradePercent,
                isPercent: true,
                exceeded: maxTradeRisk > mandate.riskPerTradePercent + 0.001
            ),
            MandateUsageRow(
                limit: .tradesPerDay,
                used: Double(maxDayCount),
                cap: Double(mandate.maxTradesPerDay),
                isPercent: false,
                exceeded: maxDayCount > mandate.maxTradesPerDay
            ),
            MandateUsageRow(
                limit: .dayRisk,
                used: maxDayLoss,
                cap: mandate.riskPerDayPercent,
                isPercent: true,
                exceeded: maxDayLoss > mandate.riskPerDayPercent + 0.001
            ),
            MandateUsageRow(
                limit: .monthRisk,
                used: maxMonthLoss,
                cap: mandate.riskPerMonthPercent,
                isPercent: true,
                exceeded: maxMonthLoss > mandate.riskPerMonthPercent + 0.001
            ),
            MandateUsageRow(
                limit: .instrument,
                used: maxInstrument,
                cap: mandate.maxInstrumentPercent,
                isPercent: true,
                exceeded: maxInstrument > mandate.maxInstrumentPercent + 0.001
            ),
            MandateUsageRow(
                limit: .group,
                used: maxGroup,
                cap: mandate.maxGroupPercent,
                isPercent: true,
                exceeded: maxGroup > mandate.maxGroupPercent + 0.001
            ),
            MandateUsageRow(
                limit: .factor,
                used: maxFactor,
                cap: mandate.maxFactorPercent,
                isPercent: true,
                exceeded: maxFactor > mandate.maxFactorPercent + 0.001
            )
        ]

        return report
    }

    /// Группа связанных инструментов: общая валюта ноги.
    static func clusterKey(_ symbol: String) -> String {
        let clean = symbol.uppercased()
        guard clean.count >= 6 else { return clean }
        let base = String(clean.prefix(3))
        let quote = String(clean.suffix(3))
        return [quote, base].contains("USD") ? "USD" : quote
    }

    /// Фактор: валюта, на которую сделана ставка.
    static func factorKey(_ symbol: String, _ direction: Direction) -> String {
        let clean = symbol.uppercased()
        guard clean.count >= 6 else { return clean }
        let base = String(clean.prefix(3))
        let quote = String(clean.suffix(3))
        if direction == .long {
            return base
        }
        return quote
    }

    private static func monthStart(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

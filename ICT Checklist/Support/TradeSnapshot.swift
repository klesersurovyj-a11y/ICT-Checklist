//
//  TradeSnapshot.swift
//  ICT Checklist
//
//  Замороженный снимок мира на момент входа: уровни цикла, ступень лэддера,
//  банки, окно ребаланса, лимиты дня, текст и скриншоты. Сделка хранит его
//  целиком, поэтому разбор показывает то, что было на входе, а не сейчас.
//

import Foundation
import SwiftUI

struct LevelSnapshot: Codable, Hashable {
    var title: String
    var price: Double
}

struct TradeLadderSnapshot: Codable, Hashable {
    var step: Int
    var levels: [Double]
    var accumulatedR: Double
}

struct CycleSnapshot: Codable, Hashable {
    var day: Date
    var direction: String
    var trend: String
    var zone: String?
    var drHigh: Double?
    var drLow: Double?
    var pointA: Double?
    var pointB: Double?
    var pointBType: String?
    var rr: Double?
    var keyLevels: [LevelSnapshot]
    var confirmations: Int
    var confirmationsTotal: Int
    var stopDay: Bool
}

struct BankSnapshot: Codable, Hashable {
    var currency: String
    var bank: String
    var rate: String
    var expectations: String
    var oneMonth: String
    var quarter: String
    var year: String
    var bias: String
    var divergence: String
}

struct LimitsSnapshot: Codable, Hashable {
    var enabled: Bool
    var maxTrades: Int
    var maxDailyLossR: Double
    var tradesToday: Int
    var closedTodayR: Double
    var ladderStep: Int
}

struct ChecklistSnapshot: Codable, Hashable {
    var title: String
    var checked: Bool
}

struct TextSnapshot: Codable, Hashable {
    var thesis: String = ""
    var pricedIn: String = ""
    var scenarios: String = ""
    var invalidation: String = ""
    var answers: String = ""
    var note: String = ""
    var tags: [String] = []
    var checklist: [ChecklistSnapshot] = []
}

struct TradeSnapshot: Codable, Hashable {
    var createdAt: Date = .now
    var symbol: String = ""
    var direction: String = ""
    var entry: Double = 0
    var stop: Double = 0
    var takeProfit: Double = 0
    var riskUSD: Double = 0
    var plannedRR: Double = 0
    var setupName: String = ""
    var ladder: TradeLadderSnapshot?
    var cycle: CycleSnapshot?
    var banks: [BankSnapshot] = []
    var rebalancing: String = ""
    var limits: LimitsSnapshot?
    var text: TextSnapshot = TextSnapshot()
    var shotCount: Int = 0

    static func encode(_ snapshot: TradeSnapshot) -> String {
        guard let data = try? JSONEncoder().encode(snapshot) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) -> TradeSnapshot? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TradeSnapshot.self, from: data)
    }
}

enum TradeSnapshotBuilder {
    struct Input {
        var symbol: String
        var direction: Direction
        var entry: Double
        var stop: Double
        var takeProfit: Double
        var riskUSD: Double
        var plannedRR: Double
        var setupName: String
        var ladderStep: Int
        var ladderAmounts: [Double]
        var accumulatedR: Double
        var cycle: TradingCycle?
        var settings: AppSettings?
        var ladderState: RiskLadderState?
        var trades: [Trade]
        var thesis: String = ""
        var pricedIn: String = ""
        var scenarios: String = ""
        var invalidation: String = ""
        var answers: String = ""
        var note: String = ""
        var tags: [String] = []
        var checks: Set<TradeCheck> = []
        var shotCount: Int = 0
    }

    static func make(_ input: Input, date: Date = .now) -> TradeSnapshot {
        let day = input.cycle?.day ?? Calendar.current.startOfDay(for: date)
        let dayTrades = input.trades.filter {
            Calendar.current.isDate($0.tradingDay, inSameDayAs: day)
        }
        let closedTodayR = dayTrades
            .filter { $0.result != .open }
            .reduce(0) { $0 + $1.actualR }

        let settings = input.settings
        let limits = LimitsSnapshot(
            enabled: settings?.dailyLimitsEnabled ?? false,
            maxTrades: settings?.maxTradesPerDay ?? 0,
            maxDailyLossR: settings?.maxDailyLossR ?? 0,
            tradesToday: dayTrades.count,
            closedTodayR: closedTodayR,
            ladderStep: input.ladderState?.stepIndex ?? input.ladderStep
        )

        let ladder = TradeLadderSnapshot(
            step: input.ladderStep,
            levels: input.ladderAmounts,
            accumulatedR: input.ladderState?.accumulatedR ?? input.accumulatedR
        )

        let banks: [BankSnapshot] = CapitalFlows.allProfiles.map { profile in
            let currency = profile.region.currency
            let overrideRate = BankOverrides.rate(currency)
            let overrideDirection = BankOverrides.direction(currency)
            return BankSnapshot(
                currency: currency,
                bank: profile.policy.bank,
                rate: overrideRate.isEmpty ? profile.policy.metrics.policyRate : overrideRate,
                expectations: overrideDirection.isEmpty
                    ? profile.policy.expected.direction
                    : overrideDirection,
                oneMonth: profile.policy.expected.oneMonth,
                quarter: profile.policy.expected.quarter,
                year: profile.policy.expected.year,
                bias: profile.policy.bias.label,
                divergence: profile.policy.divergenceTitle
            )
        }

        let checklist = TradeCheck.allCases.map { item in
            ChecklistSnapshot(title: item.title, checked: input.checks.contains(item))
        }

        return TradeSnapshot(
            createdAt: date,
            symbol: input.symbol,
            direction: input.direction.rawValue,
            entry: input.entry,
            stop: input.stop,
            takeProfit: input.takeProfit,
            riskUSD: input.riskUSD,
            plannedRR: input.plannedRR,
            setupName: input.setupName,
            ladder: ladder,
            cycle: input.cycle.map { cycleSnapshot(from: $0) },
            banks: banks,
            rebalancing: CapitalFlows.rebalancingWindow(for: date).label,
            limits: limits,
            text: TextSnapshot(
                thesis: input.thesis,
                pricedIn: input.pricedIn,
                scenarios: input.scenarios,
                invalidation: input.invalidation,
                answers: input.answers,
                note: input.note,
                tags: input.tags,
                checklist: checklist
            ),
            shotCount: input.shotCount
        )
    }

    private static func cycleSnapshot(from cycle: TradingCycle) -> CycleSnapshot {
        CycleSnapshot(
            day: cycle.day,
            direction: cycle.direction.rawValue,
            trend: cycle.trendType.rawValue,
            zone: cycle.zone?.rawValue,
            drHigh: cycle.drHigh,
            drLow: cycle.drLow,
            pointA: cycle.pointAPrice,
            pointB: cycle.pointBPrice,
            pointBType: cycle.pointBPrice == nil ? nil : cycle.pointBType.rawValue,
            rr: cycle.computedRR,
            keyLevels: cycle.activeKeyLevels.map {
                LevelSnapshot(title: $0.type.rawValue, price: $0.price)
            },
            confirmations: cycle.confirmations.count,
            confirmationsTotal: ConfirmationKey.allCases.count,
            stopDay: cycle.stopDay
        )
    }
}

//
//  Trade.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class Trade {
    var entryDate: Date = Date()
    var tradingDay: Date = Date()
    var symbol: String = ""
    var directionRaw: String = Direction.long.rawValue
    var ladderStepIndex: Int = 0
    var riskUSD: Double = 0
    var entry: Double = 0
    var originalStop: Double = 0
    var currentStop: Double = 0
    var takeProfit: Double = 0
    var plannedRR: Double = 0
    var resultRaw: String = TradeResult.open.rawValue
    var actualR: Double = 0
    var volumeFromB: Bool = false
    var isBE: Bool = false
    var note: String = ""
    var tags: [String] = []
    var closedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \TradeShot.trade)
    var shots: [TradeShot] = []

    var cycle: TradingCycle?

    init(entryDate: Date = .now,
         tradingDay: Date = .now,
         symbol: String,
         direction: Direction,
         ladderStepIndex: Int,
         riskUSD: Double,
         entry: Double,
         stop: Double,
         takeProfit: Double,
         plannedRR: Double,
         note: String = "",
         closedAt: Date? = nil) {
        self.entryDate = entryDate
        self.tradingDay = tradingDay
        self.symbol = symbol
        self.directionRaw = direction.rawValue
        self.ladderStepIndex = ladderStepIndex
        self.riskUSD = riskUSD
        self.entry = entry
        self.originalStop = stop
        self.currentStop = stop
        self.takeProfit = takeProfit
        self.plannedRR = plannedRR
        self.resultRaw = TradeResult.open.rawValue
        self.actualR = 0
        self.volumeFromB = false
        self.isBE = false
        self.note = note
        self.tags = []
        self.closedAt = closedAt
        self.shots = []
        self.cycle = nil
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .long }
        set { directionRaw = newValue.rawValue }
    }

    var result: TradeResult {
        get { TradeResult(rawValue: resultRaw) ?? .open }
        set { resultRaw = newValue.rawValue }
    }
}

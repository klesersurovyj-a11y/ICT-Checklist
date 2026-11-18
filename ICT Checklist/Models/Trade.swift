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
    /// Явная метка рыночной структуры. Пусто — структура берётся из цикла дня.
    var structureRaw: String = ""
    /// Явная метка типа POI. Пусто — POI берётся из цикла дня.
    var poiRaw: String = ""
    var closedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \TradeShot.trade)
    var shots: [TradeShot] = []

    var cycle: TradingCycle?
    var plan: TradePlan?
    var account: TradingAccount?
    var lossReview: LossReview?
    var review: TradeReview?
    var similarReviews: [LossReview] = []
    var errorNotes: [ErrorNote] = []
    var brainNotes: [BrainNote] = []

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
        self.structureRaw = ""
        self.poiRaw = ""
        self.closedAt = closedAt
        self.shots = []
        self.cycle = nil
        self.plan = nil
        self.account = nil
        self.lossReview = nil
        self.review = nil
        self.similarReviews = []
        self.errorNotes = []
        self.brainNotes = []
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

extension Trade {
    /// Метка, выставленная вручную.
    var explicitStructure: MarketStructure? {
        MarketStructure(rawValue: structureRaw)
    }

    /// Структура рынка: сначала ручная метка, затем цикл дня.
    var structure: MarketStructure? {
        explicitStructure ?? MarketBehavior.derivedStructure(for: self)
    }

    /// POI, выставленный вручную.
    var explicitPOI: POIType? {
        POIType(rawValue: poiRaw)
    }

    /// Тип POI: сначала ручная метка, затем цикл дня.
    var poiType: POIType? {
        explicitPOI ?? MarketBehavior.derivedPOI(for: self)
    }

    var marketSession: MarketSession {
        MarketBehavior.session(for: self)
    }
}

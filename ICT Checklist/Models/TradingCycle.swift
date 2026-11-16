//
//  TradingCycle.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class TradingCycle {
    var day: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var stepRaw: Int = CycleStep.news.rawValue

    var newsEUR: Bool = false
    var newsGBP: Bool = false
    var newsUSD: Bool = false
    var newsNote: String = ""

    var ladderStepIndex: Int = 0
    var riskUSD: Double = 12
    var accumulatedR: Double = 0

    var directionRaw: String = Direction.long.rawValue
    var trendTypeRaw: String = TrendType.of_.rawValue
    var trendNote: String = ""

    var drHigh: Double?
    var drLow: Double?
    var currentPrice: Double?

    @Relationship(deleteRule: .cascade, inverse: \KeyLevel.cycle)
    var keyLevels: [KeyLevel] = []

    var aConditionSNR: Bool = false
    var aConditionOF: Bool = false
    var aConditionFractal: Bool = false

    var pointAPrice: Double?
    var pointADepth: Double?
    var pointANote: String = ""
    var pointAValid: Bool = true

    var pointBPrice: Double?
    var pointBTypeRaw: String = PointBType.fractal.rawValue
    var pointBNote: String = ""
    var pointBValid: Bool = true

    var symbol: String = "EURUSD"

    var entryPrice: Double?
    var stopPrice: Double?
    var takeProfit: Double?

    var confirmationsRaw: String = ""
    var resultRaw: String = CycleResult.draft.rawValue
    var stopDay: Bool = false
    var tpVolumeAnswered: Bool = false
    var tpVolumeGiven: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Trade.cycle)
    var trade: Trade?

    @Relationship(deleteRule: .cascade, inverse: \ScenarioRecord.cycle)
    var scenarios: [ScenarioRecord] = []

    init(day: Date = .now,
         ladderStepIndex: Int = 0,
         riskUSD: Double = 12,
         accumulatedR: Double = 0,
         symbol: String = "EURUSD") {
        self.day = day
        self.createdAt = .now
        self.updatedAt = .now
        self.stepRaw = CycleStep.news.rawValue
        self.newsEUR = false
        self.newsGBP = false
        self.newsUSD = false
        self.newsNote = ""
        self.ladderStepIndex = ladderStepIndex
        self.riskUSD = riskUSD
        self.accumulatedR = accumulatedR
        self.directionRaw = Direction.long.rawValue
        self.trendTypeRaw = TrendType.of_.rawValue
        self.trendNote = ""
        self.drHigh = nil
        self.drLow = nil
        self.currentPrice = nil
        self.keyLevels = []
        self.aConditionSNR = false
        self.aConditionOF = false
        self.aConditionFractal = false
        self.pointAPrice = nil
        self.pointADepth = nil
        self.pointANote = ""
        self.pointAValid = true
        self.pointBPrice = nil
        self.pointBTypeRaw = PointBType.fractal.rawValue
        self.pointBNote = ""
        self.pointBValid = true
        self.symbol = symbol
        self.entryPrice = nil
        self.stopPrice = nil
        self.takeProfit = nil
        self.confirmationsRaw = ""
        self.resultRaw = CycleResult.draft.rawValue
        self.stopDay = false
        self.tpVolumeAnswered = false
        self.tpVolumeGiven = false
        self.trade = nil
        self.scenarios = []
    }
}

extension TradingCycle {
    var step: CycleStep {
        get { CycleStep(rawValue: stepRaw) ?? .news }
        set { stepRaw = newValue.rawValue }
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .long }
        set { directionRaw = newValue.rawValue }
    }

    var trendType: TrendType {
        get { TrendType(rawValue: trendTypeRaw) ?? .of_ }
        set { trendTypeRaw = newValue.rawValue }
    }

    var pointBType: PointBType {
        get { PointBType(rawValue: pointBTypeRaw) ?? .fractal }
        set { pointBTypeRaw = newValue.rawValue }
    }

    var result: CycleResult {
        get { CycleResult(rawValue: resultRaw) ?? .draft }
        set { resultRaw = newValue.rawValue }
    }

    var confirmations: Set<ConfirmationKey> {
        get {
            let keys = confirmationsRaw
                .split(separator: ",")
                .map(String.init)
                .compactMap { ConfirmationKey(rawValue: $0) }
            return Set(keys)
        }
        set {
            confirmationsRaw = newValue.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    func setConfirmation(_ key: ConfirmationKey, _ isOn: Bool) {
        var set = confirmations
        if isOn {
            set.insert(key)
        } else {
            set.remove(key)
        }
        confirmations = set
    }

    var activeKeyLevels: [KeyLevel] {
        keyLevels.filter { !$0.absorbed }
    }

    var referencePrice: Double? {
        if let currentPrice, currentPrice > 0 {
            return currentPrice
        }
        return drMid
    }

    var sortedKeyLevels: [KeyLevel] {
        let reference = referencePrice
        return activeKeyLevels.sorted { first, second in
            guard let reference else { return first.price > second.price }
            let firstDistance = abs(first.price - reference)
            let secondDistance = abs(second.price - reference)
            if firstDistance == secondDistance {
                return first.price > second.price
            }
            return firstDistance < secondDistance
        }
    }

    var workingKeyLevel: KeyLevel? {
        if let marked = activeKeyLevels.first(where: { $0.isWorking }) {
            return marked
        }
        return sortedKeyLevels.first
    }

    var drMid: Double? {
        guard let drHigh, let drLow, drHigh > drLow else { return nil }
        return (drHigh + drLow) / 2
    }

    var zone: PriceZone? {
        guard let mid = drMid, let price = currentPrice, price > 0 else { return nil }
        return price >= mid ? .premium : .discount
    }

    var zoneMismatch: Bool {
        guard let zone else { return false }
        return zone != direction.expectedZone
    }

    var computedRR: Double? {
        guard let entryPrice,
              let stopPrice,
              let takeProfit,
              entryPrice > 0 else { return nil }
        let risk = abs(entryPrice - stopPrice)
        let reward = abs(takeProfit - entryPrice)
        guard risk > 0, reward > 0 else { return nil }
        return reward / risk
    }

    var aConditionsMet: Bool {
        aConditionSNR && aConditionOF && aConditionFractal
    }

    var scenarioEnded: Bool {
        !pointAValid || !pointBValid
    }

    var scenarioEndReason: String {
        if !pointAValid && !pointBValid {
            return "A и B потеряли валидность"
        }
        return pointAValid ? "B потерял валидность" : "A потерял валидность"
    }

    var sortedScenarios: [ScenarioRecord] {
        scenarios.sorted { first, second in
            if first.isCurrent != second.isCurrent { return first.isCurrent }
            if first.isSelectable != second.isSelectable { return first.isSelectable }
            if first.pointADepth != second.pointADepth { return first.pointADepth > second.pointADepth }
            return first.createdAt > second.createdAt
        }
    }

    func resetScenarioForNewPointA() {
        pointAPrice = nil
        pointADepth = nil
        pointANote = ""
        pointAValid = true
        pointBPrice = nil
        pointBType = .fractal
        pointBNote = ""
        pointBValid = true
        confirmations = []
        entryPrice = nil
        stopPrice = nil
        takeProfit = nil
        for record in scenarios {
            record.isCurrent = false
        }
        updatedAt = .now
    }
}

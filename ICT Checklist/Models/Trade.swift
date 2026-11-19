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
    /// Сделка загружена демо-базой и удаляется одной кнопкой в настройках.
    var isDemo: Bool = false
    /// Название сетапа плейбука на момент создания сделки.
    var setupName: String = ""
    /// Отмеченные пункты чек-листа сделки: список ключей через запятую.
    var checklistRaw: String = ""
    /// Меморандум инвестиционного комитета.
    var memoThesis: String = ""
    var memoPricedIn: String = ""
    var memoScenarios: String = ""
    var memoInvalidation: String = ""
    var memoAnswers: String = ""
    var memoRejectReason: String = ""
    var memoVerdictRaw: String = ""
    /// Ответы на возражения красной команды по истории: JSON словаря «ключ → ответ».
    var redTeamRepliesRaw: String = ""
    /// Возражения на входе, зафиксированные в момент создания сделки: JSON массива.
    var redTeamHistoryRaw: String = ""
    /// Замороженный снимок мира на момент входа: JSON.
    var snapshotRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TradeShot.trade)
    var shots: [TradeShot] = []

    var cycle: TradingCycle?
    var plan: TradePlan?
    var account: TradingAccount?
    var setup: PlaybookSetup?
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
        self.isDemo = false
        self.setupName = ""
        self.checklistRaw = ""
        self.memoThesis = ""
        self.memoPricedIn = ""
        self.memoScenarios = ""
        self.memoInvalidation = ""
        self.memoAnswers = ""
        self.memoRejectReason = ""
        self.memoVerdictRaw = ""
        self.redTeamRepliesRaw = ""
        self.redTeamHistoryRaw = ""
        self.snapshotRaw = ""
        self.shots = []
        self.cycle = nil
        self.plan = nil
        self.account = nil
        self.setup = nil
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

    /// Денежный результат сделки: риск в долларах, умноженный на фактический R.
    var moneyResult: Double {
        guard result != .open else { return 0 }
        return riskUSD * actualR
    }

    /// Отмеченные пункты чек-листа сделки.
    var checkedChecks: Set<TradeCheck> {
        Set(checklistRaw.split(separator: ",").compactMap { TradeCheck(rawValue: String($0)) })
    }

    var checklistProgress: Double {
        guard !TradeCheck.allCases.isEmpty else { return 1 }
        return Double(checkedChecks.count) / Double(TradeCheck.allCases.count)
    }

    /// Сделка прошла по системе: отмечены все пункты чек-листа.
    var checklistComplete: Bool {
        checkedChecks.count == TradeCheck.allCases.count
    }

    /// Переключает пункт чек-листа и сохраняет его в сделке.
    func toggleCheck(_ item: TradeCheck) {
        var set = checkedChecks
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
        checklistRaw = set.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Вердикт инвестиционного комитета по сделке.
    var memoVerdict: MemoVerdict {
        MemoVerdict(rawValue: memoVerdictRaw) ?? .none
    }

    /// Тезис записан: меморандум по сделке начат.
    var hasMemoThesis: Bool {
        !memoThesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Инвалидация записана.
    var hasMemoInvalidation: Bool {
        !memoInvalidation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Меморандум заполнен хотя бы частично.
    var hasMemo: Bool {
        hasMemoThesis
            || hasMemoInvalidation
            || !memoPricedIn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !memoScenarios.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !memoAnswers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !memoRejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Возражения красной команды по этой сделке.
    func memoObjections(minRR: Double) -> [RedTeamObjection] {
        InvestmentCommittee.objections(
            thesis: memoThesis,
            invalidation: memoInvalidation,
            checkedCount: checkedChecks.count,
            totalChecks: TradeCheck.allCases.count,
            rr: plannedRR,
            minRR: minRR
        )
    }

    /// Ответы на конкретные возражения красной команды по истории.
    var redTeamReplies: [String: String] {
        get { RedTeamHistory.decodeReplies(redTeamRepliesRaw) }
        set { redTeamRepliesRaw = RedTeamHistory.encode(replies: newValue) }
    }

    /// Возражения красной команды, зафиксированные на входе.
    var redTeamHistory: [RedTeamHistoryObjection] {
        get { RedTeamHistory.decodeHistory(redTeamHistoryRaw) }
        set { redTeamHistoryRaw = RedTeamHistory.encode(history: newValue) }
    }

    /// На все возражения по истории дан ответ.
    var redTeamHistoryAnswered: Bool {
        RedTeamHistory.isAnswered(redTeamHistory, replies: redTeamReplies)
    }

    /// Снимок мира на входе. Пусто у сделок, созданных до этой версии.
    var snapshot: TradeSnapshot? {
        get { TradeSnapshot.decode(snapshotRaw) }
        set { snapshotRaw = newValue.map(TradeSnapshot.encode) ?? "" }
    }
}

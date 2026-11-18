//
//  Backup.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// One JSON file with everything the app keeps: cycles with key levels and
/// scenarios, trades with tags and screenshots, and the settings.
struct BackupFile: Codable {
    struct SettingsRecord: Codable {
        var symbolsRaw: String
        var minRR: Double
        var ladder1: Double
        var ladder2: Double
        var ladder3: Double
        var cycleStartHour: Int
        var cycleStartMinute: Int
        var cycleEndHour: Int
        var cycleEndMinute: Int
        var reminderStartEnabled: Bool
        var reminderEndEnabled: Bool
        var dailyLimitsEnabled: Bool
        var maxDailyLossR: Double
        var maxTradesPerDay: Int
        var autoCloseEnabled: Bool? = nil

        init(_ settings: AppSettings) {
            symbolsRaw = settings.symbolsRaw
            minRR = settings.minRR
            ladder1 = settings.ladder1
            ladder2 = settings.ladder2
            ladder3 = settings.ladder3
            cycleStartHour = settings.cycleStartHour
            cycleStartMinute = settings.cycleStartMinute
            cycleEndHour = settings.cycleEndHour
            cycleEndMinute = settings.cycleEndMinute
            reminderStartEnabled = settings.reminderStartEnabled
            reminderEndEnabled = settings.reminderEndEnabled
            dailyLimitsEnabled = settings.dailyLimitsEnabled
            maxDailyLossR = settings.maxDailyLossR
            maxTradesPerDay = settings.maxTradesPerDay
            autoCloseEnabled = settings.autoCloseEnabled
        }

        func apply(to settings: AppSettings) {
            settings.symbolsRaw = symbolsRaw
            settings.minRR = minRR
            settings.ladder1 = ladder1
            settings.ladder2 = ladder2
            settings.ladder3 = ladder3
            settings.cycleStartHour = cycleStartHour
            settings.cycleStartMinute = cycleStartMinute
            settings.cycleEndHour = cycleEndHour
            settings.cycleEndMinute = cycleEndMinute
            settings.reminderStartEnabled = reminderStartEnabled
            settings.reminderEndEnabled = reminderEndEnabled
            settings.dailyLimitsEnabled = dailyLimitsEnabled
            settings.maxDailyLossR = maxDailyLossR
            settings.maxTradesPerDay = maxTradesPerDay
            settings.autoCloseEnabled = autoCloseEnabled ?? settings.autoCloseEnabled
        }
    }

    struct KeyLevelRecord: Codable {
        var typeRaw: String
        var price: Double
        var note: String
        var absorbed: Bool
        var isWorking: Bool
        var createdAt: Date

        init(_ level: KeyLevel) {
            typeRaw = level.typeRaw
            price = level.price
            note = level.note
            absorbed = level.absorbed
            isWorking = level.isWorking
            createdAt = level.createdAt
        }

        func makeModel() -> KeyLevel {
            let level = KeyLevel(
                type: KeyLevelType(rawValue: typeRaw) ?? .snr,
                price: price,
                note: note,
                absorbed: absorbed,
                isWorking: isWorking
            )
            level.createdAt = createdAt
            return level
        }
    }

    struct ScenarioItem: Codable {
        var pointAPrice: Double
        var pointADepth: Double
        var pointBPrice: Double?
        var pointBTypeRaw: String
        var pointAValid: Bool
        var pointBValid: Bool
        var isCurrent: Bool
        var createdAt: Date

        init(_ record: ScenarioRecord) {
            pointAPrice = record.pointAPrice
            pointADepth = record.pointADepth
            pointBPrice = record.pointBPrice
            pointBTypeRaw = record.pointBTypeRaw
            pointAValid = record.pointAValid
            pointBValid = record.pointBValid
            isCurrent = record.isCurrent
            createdAt = record.createdAt
        }

        func makeModel() -> ScenarioRecord {
            let record = ScenarioRecord(
                pointAPrice: pointAPrice,
                pointADepth: pointADepth,
                pointAValid: pointAValid
            )
            record.pointBPrice = pointBPrice
            record.pointBTypeRaw = pointBTypeRaw
            record.pointBValid = pointBValid
            record.isCurrent = isCurrent
            record.createdAt = createdAt
            return record
        }
    }

    struct ShotItem: Codable {
        var fileName: String
        var imageData: Data?
        var createdAt: Date
        var roleRaw: String? = nil

        init(_ shot: TradeShot) {
            fileName = shot.fileName
            imageData = shot.imageData
            createdAt = shot.createdAt
            roleRaw = shot.roleRaw
        }

        func makeModel() -> TradeShot {
            TradeShot(
                fileName: fileName,
                imageData: imageData,
                createdAt: createdAt,
                role: ShotRole(rawValue: roleRaw ?? "") ?? .general
            )
        }
    }

    struct TradeRecord: Codable {
        var entryDate: Date
        var tradingDay: Date
        var symbol: String
        var directionRaw: String
        var ladderStepIndex: Int
        var riskUSD: Double
        var entry: Double
        var originalStop: Double
        var currentStop: Double
        var takeProfit: Double
        var plannedRR: Double
        var resultRaw: String
        var actualR: Double
        var volumeFromB: Bool
        var isBE: Bool
        var note: String
        var tags: [String]
        var structureRaw: String? = nil
        var poiRaw: String? = nil
        var reviewEntryReason: String? = nil
        var reviewMarketContext: String? = nil
        var reviewResultReason: String? = nil
        var reviewAdherenceRaw: String? = nil
        var closedAt: Date?
        var cycleDay: Date?
        var accountKey: String?
        var shots: [ShotItem]

        init(_ trade: Trade) {
            entryDate = trade.entryDate
            tradingDay = trade.tradingDay
            symbol = trade.symbol
            directionRaw = trade.directionRaw
            ladderStepIndex = trade.ladderStepIndex
            riskUSD = trade.riskUSD
            entry = trade.entry
            originalStop = trade.originalStop
            currentStop = trade.currentStop
            takeProfit = trade.takeProfit
            plannedRR = trade.plannedRR
            resultRaw = trade.resultRaw
            actualR = trade.actualR
            volumeFromB = trade.volumeFromB
            isBE = trade.isBE
            note = trade.note
            tags = trade.tags
            structureRaw = trade.structureRaw
            poiRaw = trade.poiRaw
            if let review = trade.review {
                reviewEntryReason = review.entryReason.isEmpty ? nil : review.entryReason
                reviewMarketContext = review.marketContext.isEmpty ? nil : review.marketContext
                reviewResultReason = review.resultReason.isEmpty ? nil : review.resultReason
                reviewAdherenceRaw = review.adherence == .unknown ? nil : review.adherenceRaw
            }
            closedAt = trade.closedAt
            cycleDay = trade.cycle?.day
            accountKey = trade.account.map { "\($0.name)|\($0.typeRaw)" }
            shots = trade.shots.map(ShotItem.init)
        }

        func makeModel(context: ModelContext) -> Trade {
            let trade = Trade(
                entryDate: entryDate,
                tradingDay: tradingDay,
                symbol: symbol,
                direction: Direction(rawValue: directionRaw) ?? .long,
                ladderStepIndex: ladderStepIndex,
                riskUSD: riskUSD,
                entry: entry,
                stop: originalStop,
                takeProfit: takeProfit,
                plannedRR: plannedRR,
                note: note,
                closedAt: closedAt
            )
            trade.currentStop = currentStop
            trade.resultRaw = resultRaw
            trade.actualR = actualR
            trade.volumeFromB = volumeFromB
            trade.isBE = isBE
            trade.tags = tags
            trade.structureRaw = structureRaw ?? ""
            trade.poiRaw = poiRaw ?? ""
            context.insert(trade)

            if reviewEntryReason != nil
                || reviewMarketContext != nil
                || reviewResultReason != nil
                || reviewAdherenceRaw != nil {
                let review = TradeReview(trade: trade)
                review.entryReason = reviewEntryReason ?? ""
                review.marketContext = reviewMarketContext ?? ""
                review.resultReason = reviewResultReason ?? ""
                if let raw = reviewAdherenceRaw,
                   let adherence = AlgorithmAdherence(rawValue: raw) {
                    review.adherenceRaw = adherence.rawValue
                }
                context.insert(review)
                trade.review = review
            }

            for shot in shots {
                let item = shot.makeModel()
                context.insert(item)
                trade.shots.append(item)
            }
            return trade
        }
    }

    struct CycleRecord: Codable {
        var day: Date
        var createdAt: Date
        var updatedAt: Date
        var stepRaw: Int
        var newsEUR: Bool
        var newsGBP: Bool
        var newsUSD: Bool
        var newsNote: String
        var ladderStepIndex: Int
        var riskUSD: Double
        var accumulatedR: Double
        var directionRaw: String
        var trendTypeRaw: String
        var trendNote: String
        var drHigh: Double?
        var drLow: Double?
        var currentPrice: Double?
        var aConditionSNR: Bool
        var aConditionOF: Bool
        var aConditionFractal: Bool
        var pointAPrice: Double?
        var pointADepth: Double?
        var pointANote: String
        var pointAValid: Bool
        var pointBPrice: Double?
        var pointBTypeRaw: String
        var pointBNote: String
        var pointBValid: Bool
        var symbol: String
        var entryPrice: Double?
        var stopPrice: Double?
        var takeProfit: Double?
        var confirmationsRaw: String
        var resultRaw: String
        var stopDay: Bool
        var tpVolumeAnswered: Bool
        var tpVolumeGiven: Bool
        var keyLevels: [KeyLevelRecord]
        var scenarios: [ScenarioItem]

        init(_ cycle: TradingCycle) {
            day = cycle.day
            createdAt = cycle.createdAt
            updatedAt = cycle.updatedAt
            stepRaw = cycle.stepRaw
            newsEUR = cycle.newsEUR
            newsGBP = cycle.newsGBP
            newsUSD = cycle.newsUSD
            newsNote = cycle.newsNote
            ladderStepIndex = cycle.ladderStepIndex
            riskUSD = cycle.riskUSD
            accumulatedR = cycle.accumulatedR
            directionRaw = cycle.directionRaw
            trendTypeRaw = cycle.trendTypeRaw
            trendNote = cycle.trendNote
            drHigh = cycle.drHigh
            drLow = cycle.drLow
            currentPrice = cycle.currentPrice
            aConditionSNR = cycle.aConditionSNR
            aConditionOF = cycle.aConditionOF
            aConditionFractal = cycle.aConditionFractal
            pointAPrice = cycle.pointAPrice
            pointADepth = cycle.pointADepth
            pointANote = cycle.pointANote
            pointAValid = cycle.pointAValid
            pointBPrice = cycle.pointBPrice
            pointBTypeRaw = cycle.pointBTypeRaw
            pointBNote = cycle.pointBNote
            pointBValid = cycle.pointBValid
            symbol = cycle.symbol
            entryPrice = cycle.entryPrice
            stopPrice = cycle.stopPrice
            takeProfit = cycle.takeProfit
            confirmationsRaw = cycle.confirmationsRaw
            resultRaw = cycle.resultRaw
            stopDay = cycle.stopDay
            tpVolumeAnswered = cycle.tpVolumeAnswered
            tpVolumeGiven = cycle.tpVolumeGiven
            keyLevels = cycle.keyLevels.map(KeyLevelRecord.init)
            scenarios = cycle.scenarios.map(ScenarioItem.init)
        }

        func makeModel(context: ModelContext) -> TradingCycle {
            let cycle = TradingCycle(
                day: day,
                ladderStepIndex: ladderStepIndex,
                riskUSD: riskUSD,
                accumulatedR: accumulatedR,
                symbol: symbol
            )
            cycle.createdAt = createdAt
            cycle.updatedAt = updatedAt
            cycle.stepRaw = stepRaw
            cycle.newsEUR = newsEUR
            cycle.newsGBP = newsGBP
            cycle.newsUSD = newsUSD
            cycle.newsNote = newsNote
            cycle.directionRaw = directionRaw
            cycle.trendTypeRaw = trendTypeRaw
            cycle.trendNote = trendNote
            cycle.drHigh = drHigh
            cycle.drLow = drLow
            cycle.currentPrice = currentPrice
            cycle.aConditionSNR = aConditionSNR
            cycle.aConditionOF = aConditionOF
            cycle.aConditionFractal = aConditionFractal
            cycle.pointAPrice = pointAPrice
            cycle.pointADepth = pointADepth
            cycle.pointANote = pointANote
            cycle.pointAValid = pointAValid
            cycle.pointBPrice = pointBPrice
            cycle.pointBTypeRaw = pointBTypeRaw
            cycle.pointBNote = pointBNote
            cycle.pointBValid = pointBValid
            cycle.entryPrice = entryPrice
            cycle.stopPrice = stopPrice
            cycle.takeProfit = takeProfit
            cycle.confirmationsRaw = confirmationsRaw
            cycle.resultRaw = resultRaw
            cycle.stopDay = stopDay
            cycle.tpVolumeAnswered = tpVolumeAnswered
            cycle.tpVolumeGiven = tpVolumeGiven
            context.insert(cycle)

            for record in keyLevels {
                let level = record.makeModel()
                context.insert(level)
                cycle.keyLevels.append(level)
            }

            for record in scenarios {
                let scenario = record.makeModel()
                context.insert(scenario)
                cycle.scenarios.append(scenario)
            }

            return cycle
        }
    }

    struct AccountRecord: Codable {
        var name: String
        var typeRaw: String
        var currency: String
        var createdAt: Date
        var isArchived: Bool
        var startingBalance: Double? = nil
        var operations: [OperationRecord]

        init(_ account: TradingAccount) {
            name = account.name
            typeRaw = account.typeRaw
            currency = account.currency
            createdAt = account.createdAt
            isArchived = account.isArchived
            startingBalance = account.startingBalance
            operations = account.operations.map(OperationRecord.init)
        }

        func makeModel(context: ModelContext) -> TradingAccount {
            let account = TradingAccount(
                name: name,
                type: AccountType(rawValue: typeRaw) ?? .personal,
                currency: currency,
                startingBalance: startingBalance ?? 0
            )
            account.createdAt = createdAt
            account.isArchived = isArchived
            context.insert(account)

            for record in operations {
                let operation = record.makeModel()
                context.insert(operation)
                account.operations.append(operation)
            }
            return account
        }
    }

    struct OperationRecord: Codable {
        var kindRaw: String
        var amount: Double
        var date: Date
        var note: String
        var createdAt: Date
        var transferID: String? = nil
        var isTransferIncoming: Bool? = nil

        init(_ operation: AccountOperation) {
            kindRaw = operation.kindRaw
            amount = operation.amount
            date = operation.date
            note = operation.note
            createdAt = operation.createdAt
            transferID = operation.transferID
            isTransferIncoming = operation.isTransferIncoming
        }

        func makeModel() -> AccountOperation {
            let operation = AccountOperation(
                kind: AccountOperationKind(rawValue: kindRaw) ?? .payout,
                amount: amount,
                date: date,
                note: note
            )
            operation.createdAt = createdAt
            operation.transferID = transferID ?? ""
            operation.isTransferIncoming = isTransferIncoming ?? false
            return operation
        }
    }

    struct TradeRef: Codable {
        var entry: Date
        var day: Date
    }

    struct PhotoItem: Codable {
        var imageData: Data?
        var createdAt: Date

        init(_ shot: ErrorShot) {
            imageData = shot.imageData
            createdAt = shot.createdAt
        }

        func makeModel() -> ErrorShot {
            ErrorShot(imageData: imageData, createdAt: createdAt)
        }
    }

    struct ErrorNoteRecord: Codable {
        var title: String
        var text: String
        var statusRaw: String
        var createdAt: Date
        var updatedAt: Date
        var trades: [TradeRef]
        var shots: [PhotoItem]? = nil

        init(_ note: ErrorNote) {
            title = note.title
            text = note.text
            statusRaw = note.statusRaw
            createdAt = note.createdAt
            updatedAt = note.updatedAt
            trades = note.trades.map { TradeRef(entry: $0.entryDate, day: $0.tradingDay) }
            shots = note.shots.map(PhotoItem.init)
        }

        func makeModel(context: ModelContext) -> ErrorNote {
            let note = ErrorNote(
                title: title,
                text: text,
                status: ErrorStatus(rawValue: statusRaw) ?? .awaiting
            )
            note.createdAt = createdAt
            note.updatedAt = updatedAt
            context.insert(note)
            return note
        }
    }

    struct BrainPhotoItem: Codable {
        var imageData: Data?
        var createdAt: Date

        init(_ shot: BrainShot) {
            imageData = shot.imageData
            createdAt = shot.createdAt
        }

        func makeModel() -> BrainShot {
            BrainShot(imageData: imageData, createdAt: createdAt)
        }
    }

    struct BrainNoteRecord: Codable {
        var kindRaw: String
        var statusRaw: String? = nil
        var title: String
        var topic: String
        var summary: String
        var keyRaw: String
        var benefits: String
        var schematic: String
        var chartExamples: String
        var conclusions: String
        var createdAt: Date
        var updatedAt: Date
        var popularity: Int
        var trades: [TradeRef]
        var photos: [BrainPhotoItem]? = nil

        init(_ note: BrainNote) {
            kindRaw = note.kindRaw
            statusRaw = note.statusRaw
            title = note.title
            topic = note.topic
            summary = note.summary
            keyRaw = note.keyRaw
            benefits = note.benefits
            schematic = note.schematic
            chartExamples = note.chartExamples
            conclusions = note.conclusions
            createdAt = note.createdAt
            updatedAt = note.updatedAt
            popularity = note.popularity
            trades = note.trades.map { TradeRef(entry: $0.entryDate, day: $0.tradingDay) }
            photos = note.photos.map(BrainPhotoItem.init)
        }

        func makeModel(context: ModelContext) -> BrainNote {
            let note = BrainNote(
                kind: BrainKind(rawValue: kindRaw) ?? .keyNote,
                title: title,
                topic: topic
            )
            note.summary = summary
            note.statusRaw = BrainStatus(rawValue: statusRaw ?? "")?.rawValue ?? BrainStatus.idea.rawValue
            note.keyRaw = keyRaw
            note.benefits = benefits
            note.schematic = schematic
            note.chartExamples = chartExamples
            note.conclusions = conclusions
            note.createdAt = createdAt
            note.updatedAt = updatedAt
            note.popularity = popularity
            context.insert(note)
            return note
        }
    }

    struct JournalRecord: Codable {
        var day: Date
        var moodRaw: String
        var note: String
        var improve: String
        var createdAt: Date
        var updatedAt: Date

        init(_ entry: JournalEntry) {
            day = entry.day
            moodRaw = entry.moodRaw
            note = entry.note
            improve = entry.improve
            createdAt = entry.createdAt
            updatedAt = entry.updatedAt
        }

        func makeModel(context: ModelContext) -> JournalEntry {
            let entry = JournalEntry(
                day: day,
                mood: JournalMood(rawValue: moodRaw) ?? .calm,
                note: note,
                improve: improve
            )
            entry.createdAt = createdAt
            entry.updatedAt = updatedAt
            context.insert(entry)
            return entry
        }
    }

    struct WeekScenarioRecord: Codable {
        var title: String
        var note: String
        var position: Int
        var createdAt: Date

        init(_ scenario: WeekScenario) {
            title = scenario.title
            note = scenario.note
            position = scenario.position
            createdAt = scenario.createdAt
        }

        func makeModel() -> WeekScenario {
            let scenario = WeekScenario(title: title, note: note, position: position)
            scenario.createdAt = createdAt
            return scenario
        }
    }

    struct WeekPlanRecord: Codable {
        var weekStart: Date
        var theme: String
        var targetR: Double
        var review: String? = nil
        var createdAt: Date
        var updatedAt: Date
        var scenarios: [WeekScenarioRecord]? = nil

        init(_ plan: WeekPlan) {
            weekStart = plan.weekStart
            theme = plan.theme
            targetR = plan.targetR
            review = plan.review
            createdAt = plan.createdAt
            updatedAt = plan.updatedAt
            scenarios = plan.sortedScenarios.map(WeekScenarioRecord.init)
        }

        func makeModel(context: ModelContext) -> WeekPlan {
            let plan = WeekPlan(weekStart: weekStart, theme: theme, targetR: targetR)
            plan.review = review ?? ""
            plan.createdAt = createdAt
            plan.updatedAt = updatedAt
            context.insert(plan)

            for record in scenarios ?? [] {
                let scenario = record.makeModel()
                context.insert(scenario)
                plan.scenarios.append(scenario)
            }
            return plan
        }
    }

    var version: Int
    var createdAt: Date
    var settings: SettingsRecord?
    var cycles: [CycleRecord]
    var trades: [TradeRecord]
    var accounts: [AccountRecord]? = nil
    var errors: [ErrorNoteRecord]? = nil
    var brainNotes: [BrainNoteRecord]? = nil
    var journal: [JournalRecord]? = nil
    var weekPlans: [WeekPlanRecord]? = nil
}

// MARK: - Store

enum BackupStore {
    enum BackupError: Error {
        case encoding
        case decoding
    }

    struct RestoreResult {
        var trades: Int = 0
        var cycles: Int = 0
        var errors: Int = 0
        var skippedTrades: Int = 0
        var skippedCycles: Int = 0
    }

    private struct TradeKey: Hashable {
        let entry: Date
        let day: Date
    }

    static func writeFile(
        cycles: [TradingCycle],
        trades: [Trade],
        settings: AppSettings?,
        accounts: [TradingAccount] = [],
        errors: [ErrorNote] = [],
        brain: [BrainNote] = [],
        journal: [JournalEntry] = [],
        weeks: [WeekPlan] = []
    ) throws -> URL {
        let file = BackupFile(
            version: 1,
            createdAt: .now,
            settings: settings.map(BackupFile.SettingsRecord.init),
            cycles: cycles.map(BackupFile.CycleRecord.init),
            trades: trades.map(BackupFile.TradeRecord.init),
            accounts: accounts.map(BackupFile.AccountRecord.init),
            errors: errors.map(BackupFile.ErrorNoteRecord.init),
            brainNotes: brain.map(BackupFile.BrainNoteRecord.init),
            journal: journal.map(BackupFile.JournalRecord.init),
            weekPlans: weeks.map(BackupFile.WeekPlanRecord.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(file) else {
            throw BackupError.encoding
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — копия \(stampFormatter.string(from: .now)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func restore(from data: Data, context: ModelContext) throws -> RestoreResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let file = try? decoder.decode(BackupFile.self, from: data) else {
            throw BackupError.decoding
        }

        let calendar = Calendar.current
        let existingCycles = (try? context.fetch(FetchDescriptor<TradingCycle>())) ?? []
        let existingTrades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let existingAccounts = (try? context.fetch(FetchDescriptor<TradingAccount>())) ?? []
        let existingErrors = (try? context.fetch(FetchDescriptor<ErrorNote>())) ?? []
        let existingBrainNotes = (try? context.fetch(FetchDescriptor<BrainNote>())) ?? []
        let existingJournal = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        let existingWeekPlans = (try? context.fetch(FetchDescriptor<WeekPlan>())) ?? []

        var cycleByDay: [Date: TradingCycle] = [:]
        for cycle in existingCycles {
            cycleByDay[calendar.startOfDay(for: cycle.day)] = cycle
        }

        var tradeByKey: [TradeKey: Trade] = [:]
        var tradeKeys = Set<TradeKey>()
        for trade in existingTrades {
            let key = TradeKey(
                entry: trade.entryDate,
                day: calendar.startOfDay(for: trade.tradingDay)
            )
            tradeByKey[key] = trade
            tradeKeys.insert(key)
        }

        var accountsByKey: [String: TradingAccount] = [:]
        for account in existingAccounts {
            accountsByKey["\(account.name)|\(account.typeRaw)"] = account
        }

        var result = RestoreResult()

        if let record = file.settings {
            let list = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
            if let existing = list.first {
                record.apply(to: existing)
            } else {
                let created = AppSettings()
                context.insert(created)
                record.apply(to: created)
            }
        }

        // Счета восстанавливаются первыми, чтобы сделки нашли свой счёт.
        for record in file.accounts ?? [] {
            let key = "\(record.name)|\(record.typeRaw)"
            if accountsByKey[key] != nil {
                continue
            }
            let account = record.makeModel(context: context)
            accountsByKey[key] = account
        }

        for record in file.cycles {
            let day = calendar.startOfDay(for: record.day)
            if cycleByDay[day] != nil {
                result.skippedCycles += 1
                continue
            }
            let cycle = record.makeModel(context: context)
            cycleByDay[day] = cycle
            result.cycles += 1
        }

        for record in file.trades {
            let key = TradeKey(
                entry: record.entryDate,
                day: calendar.startOfDay(for: record.tradingDay)
            )
            if tradeKeys.contains(key) {
                result.skippedTrades += 1
                continue
            }

            let trade = record.makeModel(context: context)

            if let cycleDay = record.cycleDay.map({ calendar.startOfDay(for: $0) }),
               let cycle = cycleByDay[cycleDay],
               cycle.trade == nil {
                trade.cycle = cycle
                cycle.trade = trade
            }

            if let accountKey = record.accountKey,
               let account = accountsByKey[accountKey] {
                trade.account = account
            }

            tradeKeys.insert(key)
            tradeByKey[key] = trade
            result.trades += 1
        }

        var errorKeys = Set(
            existingErrors.map { errorKey(title: $0.title, createdAt: $0.createdAt) }
        )
        for record in file.errors ?? [] {
            let key = errorKey(title: record.title, createdAt: record.createdAt)
            if errorKeys.contains(key) {
                continue
            }

            let note = record.makeModel(context: context)

            for ref in record.trades {
                let tradeKey = TradeKey(
                    entry: ref.entry,
                    day: calendar.startOfDay(for: ref.day)
                )
                if let trade = tradeByKey[tradeKey] {
                    note.attach(trade)
                }
            }

            for photo in record.shots ?? [] {
                let shot = photo.makeModel()
                context.insert(shot)
                note.shots.append(shot)
            }

            note.updatedAt = record.updatedAt
            errorKeys.insert(key)
            result.errors += 1
        }

        var brainKeys = Set(
            existingBrainNotes.map { errorKey(title: $0.title, createdAt: $0.createdAt) }
        )
        for record in file.brainNotes ?? [] {
            let key = errorKey(title: record.title, createdAt: record.createdAt)
            if brainKeys.contains(key) {
                continue
            }

            let note = record.makeModel(context: context)

            for ref in record.trades {
                let tradeKey = TradeKey(
                    entry: ref.entry,
                    day: calendar.startOfDay(for: ref.day)
                )
                if let trade = tradeByKey[tradeKey] {
                    note.attach(trade)
                }
            }

            for photo in record.photos ?? [] {
                let shot = photo.makeModel()
                context.insert(shot)
                note.photos.append(shot)
            }

            note.updatedAt = record.updatedAt
            brainKeys.insert(key)
        }

        var journalDays = Set(
            existingJournal.map { calendar.startOfDay(for: $0.day) }
        )
        for record in file.journal ?? [] {
            let day = calendar.startOfDay(for: record.day)
            if journalDays.contains(day) {
                continue
            }
            _ = record.makeModel(context: context)
            journalDays.insert(day)
        }

        var weekStarts = Set(
            existingWeekPlans.map { calendar.startOfDay(for: $0.weekStart) }
        )
        for record in file.weekPlans ?? [] {
            let start = calendar.startOfDay(for: record.weekStart)
            if weekStarts.contains(start) {
                continue
            }
            _ = record.makeModel(context: context)
            weekStarts.insert(start)
        }

        try context.save()
        return result
    }

    private static func errorKey(title: String, createdAt: Date) -> String {
        "\(title)|\(createdAt.timeIntervalSince1970)"
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter
    }()
}

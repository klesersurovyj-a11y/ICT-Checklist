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

        init(_ shot: TradeShot) {
            fileName = shot.fileName
            imageData = shot.imageData
            createdAt = shot.createdAt
        }

        func makeModel() -> TradeShot {
            TradeShot(fileName: fileName, imageData: imageData, createdAt: createdAt)
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
        var closedAt: Date?
        var cycleDay: Date?
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
            closedAt = trade.closedAt
            cycleDay = trade.cycle?.day
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
            context.insert(trade)

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

    var version: Int
    var createdAt: Date
    var settings: SettingsRecord?
    var cycles: [CycleRecord]
    var trades: [TradeRecord]
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
        settings: AppSettings?
    ) throws -> URL {
        let file = BackupFile(
            version: 1,
            createdAt: .now,
            settings: settings.map(BackupFile.SettingsRecord.init),
            cycles: cycles.map(BackupFile.CycleRecord.init),
            trades: trades.map(BackupFile.TradeRecord.init)
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

        var cycleByDay: [Date: TradingCycle] = [:]
        for cycle in existingCycles {
            cycleByDay[calendar.startOfDay(for: cycle.day)] = cycle
        }

        var tradeKeys = Set(
            existingTrades.map {
                TradeKey(entry: $0.entryDate, day: calendar.startOfDay(for: $0.tradingDay))
            }
        )

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

            tradeKeys.insert(key)
            result.trades += 1
        }

        try context.save()
        return result
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter
    }()
}

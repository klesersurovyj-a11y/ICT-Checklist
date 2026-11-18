//
//  DemoData.swift
//  ICT Checklist
//
//  Демо-база для первого запуска: примерные сделки, планы дня,
//  записи Second Brain и один демо-счёт. Удаляется одной кнопкой в настройках.
//

import Foundation
import SwiftData

enum DemoData {
    static let tradeCount = 12
    static let planCount = 3
    static let noteCount = 6

    // MARK: - Seeding

    @discardableResult
    static func seed(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func moment(_ offset: Int, hour: Int) -> Date {
            calendar.date(byAdding: .hour, value: hour, to: day(offset)) ?? day(offset)
        }

        // Счёт, к которому привязаны примерные сделки.
        let account = TradingAccount(
            name: "Demo · ICT Checklist",
            type: .demo,
            currency: "USD",
            startingBalance: 1_000
        )
        account.isDemo = true
        context.insert(account)

        // Планы дня.
        var plans: [TradePlan] = []

        let planSpecs: [(offset: Int, symbol: String, direction: Direction, title: String, thesis: String, a: String, b: String, result: PlanResult)] = [
            (
                -14,
                "GBPUSD",
                .long,
                "Снятие азиатского лоу и ход к PDH",
                "Азия собрала ликвидность под лоу, Лондон даёт реакцию вверх.",
                "Жду снятие лоу → возврат в диапазон → вход от SNR H1 к PDH.",
                "Если снятие не даёт реакции — вход от FVG в продолжение потока.",
                .win
            ),
            (
                -7,
                "XAUUSD",
                .short,
                "Контрвход от OB после SOF",
                "Недельный поток вверх, но на H4 сменился — ищу короткую.",
                "SOF на H4 → вход от OB → цель 0.5 DR вниз.",
                "Перевод в безубыток при подходе к 0.5 DR.",
                .loss
            ),
            (
                -3,
                "EURUSD",
                .long,
                "Ретест FVG и продолжение потока",
                "OF вверх, цена вернулась к FVG М15.",
                "Вход от FVG после реакции, стоп под свинг, цель — PDH.",
                "Без входа, если FVG пробит телом свечи.",
                .win
            )
        ]

        for spec in planSpecs {
            let plan = TradePlan(day: day(spec.offset), symbol: spec.symbol, direction: spec.direction)
            plan.title = spec.title
            plan.thesis = spec.thesis
            plan.planA = spec.a
            plan.planB = spec.b
            plan.result = spec.result
            plan.isDemo = true
            context.insert(plan)
            plans.append(plan)
        }

        // Сделки.
        let tradeSpecs: [DemoTradeSpec] = [
            .init(dayOffset: -21, symbol: "EURUSD", direction: .long,
                  entry: 1.08420, stop: 1.08120, take: 1.09020,
                  risk: 12, result: .tp, r: 2.0, structure: .trend, poi: .fvg,
                  tags: ["Лондон"], note: "Вход от FVG после снятия азиатского лоу."),
            .init(dayOffset: -19, symbol: "XAUUSD", direction: .short,
                  entry: 2324.50, stop: 2329.50, take: 2314.50,
                  risk: 12, result: .sl, r: -1.0, structure: .reversal, poi: .orderBlock,
                  tags: ["Нью-Йорк"], note: "Контрвход от OB — не дождался подтверждения."),
            .init(dayOffset: -17, symbol: "GBPUSD", direction: .long,
                  entry: 1.27120, stop: 1.26820, take: 1.27720,
                  risk: 12, result: .tp, r: 2.0, structure: .trend, poi: .snr,
                  tags: ["Лондон"], note: "Тест SNR на H1 и вход в поток."),
            .init(dayOffset: -14, symbol: "EURUSD", direction: .short,
                  entry: 1.09210, stop: 1.09510, take: 1.08610,
                  risk: 12, result: .be, r: 0.0, structure: .correction, poi: .equilibrium,
                  tags: ["Лондон"], note: "Перенёс в безубыток при подходе к 0.5 DR."),
            .init(dayOffset: -12, symbol: "XAUUSD", direction: .long,
                  entry: 2308.00, stop: 2303.00, take: 2318.00,
                  risk: 25, result: .tp, r: 2.0, structure: .trend, poi: .fvg,
                  tags: ["Азия"], note: "Вход от FVG в продолжение потока."),
            .init(dayOffset: -10, symbol: "USDJPY", direction: .long,
                  entry: 156.20, stop: 155.70, take: 157.20,
                  risk: 12, result: .sl, r: -1.0, structure: .reversal, poi: .fractal,
                  tags: ["Токио"], note: "Реакция на фрактал не подтвердилась."),
            .init(dayOffset: -8, symbol: "GBPUSD", direction: .short,
                  entry: 1.27940, stop: 1.28240, take: 1.27340,
                  risk: 12, result: .tp, r: 2.0, structure: .correction, poi: .rangeEdge,
                  tags: ["Лондон"], note: "Снятие PDH и возврат в диапазон."),
            .init(dayOffset: -7, symbol: "EURUSD", direction: .long,
                  entry: 1.07980, stop: 1.07680, take: 1.08580,
                  risk: 25, result: .sl, r: -1.0, structure: .trend, poi: .snr,
                  tags: ["Нью-Йорк"], note: "Поздний вход в тренд перед новостями."),
            .init(dayOffset: -5, symbol: "XAUUSD", direction: .short,
                  entry: 2340.10, stop: 2345.10, take: 2330.10,
                  risk: 12, result: .tp, r: 2.0, structure: .reversal, poi: .orderBlock,
                  tags: ["Нью-Йорк"], note: "SOF и вход от OB в Нью-Йорке."),
            .init(dayOffset: -3, symbol: "GBPUSD", direction: .long,
                  entry: 1.26550, stop: 1.26250, take: 1.27150,
                  risk: 12, result: .tp, r: 2.0, structure: .trend, poi: .fvg,
                  tags: ["Лондон"], note: "Продолжение потока после ретеста FVG."),
            .init(dayOffset: -2, symbol: "EURUSD", direction: .short,
                  entry: 1.08760, stop: 1.09060, take: 1.08160,
                  risk: 25, result: .sl, r: -1.0, structure: .correction, poi: .equilibrium,
                  tags: ["Лондон"], note: "Вход против недельного потока — нарушение правила."),
            .init(dayOffset: -1, symbol: "XAUUSD", direction: .long,
                  entry: 2320.00, stop: 2315.00, take: 2330.00,
                  risk: 12, result: .open, r: 0.0, structure: .trend, poi: .snr,
                  tags: ["Нью-Йорк"], note: "Открыта, жду реакцию на уровень.")
        ]

        var trades: [Trade] = []

        for spec in tradeSpecs {
            let entryDate = moment(spec.dayOffset, hour: 11)
            let closedAt = spec.result == .open ? nil : moment(spec.dayOffset, hour: 14)

            let trade = Trade(
                entryDate: entryDate,
                tradingDay: day(spec.dayOffset),
                symbol: spec.symbol,
                direction: spec.direction,
                ladderStepIndex: spec.risk > 12 ? 1 : 0,
                riskUSD: spec.risk,
                entry: spec.entry,
                stop: spec.stop,
                takeProfit: spec.take,
                plannedRR: 2.0,
                note: spec.note,
                closedAt: closedAt
            )
            trade.result = spec.result
            trade.actualR = spec.r
            trade.isBE = spec.result == .be
            trade.currentStop = spec.result == .be ? spec.entry : spec.stop
            trade.tags = spec.tags
            trade.structureRaw = spec.structure.rawValue
            trade.poiRaw = spec.poi.rawValue
            trade.account = account
            trade.isDemo = true

            context.insert(trade)
            trades.append(trade)
        }

        // Примеры связи плана и сделки.
        if trades.count > 9, plans.count > 2 {
            trades[9].plan = plans[2]
        }
        if trades.count > 7, plans.count > 1 {
            trades[7].plan = plans[1]
        }
        if trades.count > 2, plans.count > 0 {
            trades[2].plan = plans[0]
        }

        // Second Brain.
        let notes: [BrainNote] = [
            makeNote(
                kind: .observation,
                status: .confirmed,
                title: "Снятие азиатского лоу перед Лондоном",
                topic: "Сессии",
                summary: "Когда Азия собирает ликвидность под лоу, Лондон чаще всего даёт импульс в противоположную сторону.",
                key: "Ликвидность под лоу снята\nРеакция в первые 30 минут\nЦель — PDH или граница диапазона",
                conclusions: "Сделки по этой схеме дают лучший winrate в лондонскую сессию.",
                context: context
            ),
            makeNote(
                kind: .hypothesis,
                status: .testing,
                title: "Вход только после реакции H4 повышает winrate",
                topic: "Вход",
                summary: "Проверяю, помогает ли ожидание закрытия свечи H4 перед входом.",
                key: "Сигнал на H4\nРеакция на POI\nТолько потом вход",
                conclusions: "Нужно ещё 10 сделок для вывода.",
                context: context
            ),
            makeNote(
                kind: .rule,
                status: .confirmed,
                title: "Риск по ступени и вход после теста SNR",
                topic: "Система",
                summary: "Риск не выше текущей ступени лестницы, вход только после теста уровня.",
                key: "Риск = ступень\nВход после теста SNR\nПропуск, если уровень пробит телом",
                conclusions: "Правило держит просадку в пределах лимита дня.",
                context: context
            ),
            makeNote(
                kind: .research,
                status: .testing,
                title: "Поведение EURUSD в первые 30 минут Лондона",
                topic: "Сессии",
                summary: "Собираю статистику по первому получасу лондонской сессии за последние 60 дней.",
                key: "Снятие азиатского диапазона\nИмпульс или ложный пробой\nРеакция на FVG М5",
                conclusions: "Пока выборка 30 наблюдений, вывод рано делать.",
                context: context
            ),
            makeNote(
                kind: .pattern,
                status: .idea,
                title: "Три TP подряд в лондонскую сессию",
                topic: "Сессии",
                summary: "Замечаю, что после двух TP подряд третья сделка в Лондоне чаще уходит в минус.",
                key: "Две сделки в плюс\nТретья — после паузы\nРиск не повышать",
                conclusions: "Проверить на истории, а не по ощущениям.",
                context: context
            ),
            makeNote(
                kind: .keyNote,
                status: .idea,
                title: "Однопоточные данные PMI",
                topic: "Новости",
                summary: "PMI выходит отдельными потоками по странам — не путать с одним релизом.",
                key: "Проверять время каждой страны\nНе входить за 15 минут до релиза",
                conclusions: "",
                context: context
            )
        ]

        for (index, note) in notes.enumerated() where index < trades.count {
            note.attach(trades[index])
        }

        try? context.save()
        return trades.count + plans.count + notes.count
    }

    // MARK: - Removal

    static func existingCount(context: ModelContext) -> Int {
        let trades = (try? context.fetch(
            FetchDescriptor<Trade>(predicate: #Predicate<Trade> { $0.isDemo })
        ))?.count ?? 0

        let plans = (try? context.fetch(
            FetchDescriptor<TradePlan>(predicate: #Predicate<TradePlan> { $0.isDemo })
        ))?.count ?? 0

        let notes = (try? context.fetch(
            FetchDescriptor<BrainNote>(predicate: #Predicate<BrainNote> { $0.isDemo })
        ))?.count ?? 0

        let accounts = (try? context.fetch(
            FetchDescriptor<TradingAccount>(predicate: #Predicate<TradingAccount> { $0.isDemo })
        ))?.count ?? 0

        return trades + plans + notes + accounts
    }

    static func remove(context: ModelContext) {
        let trades = (try? context.fetch(
            FetchDescriptor<Trade>(predicate: #Predicate<Trade> { $0.isDemo })
        )) ?? []
        for trade in trades {
            context.delete(trade)
        }

        let plans = (try? context.fetch(
            FetchDescriptor<TradePlan>(predicate: #Predicate<TradePlan> { $0.isDemo })
        )) ?? []
        for plan in plans {
            context.delete(plan)
        }

        let notes = (try? context.fetch(
            FetchDescriptor<BrainNote>(predicate: #Predicate<BrainNote> { $0.isDemo })
        )) ?? []
        for note in notes {
            context.delete(note)
        }

        let accounts = (try? context.fetch(
            FetchDescriptor<TradingAccount>(predicate: #Predicate<TradingAccount> { $0.isDemo })
        )) ?? []
        for account in accounts {
            context.delete(account)
        }

        try? context.save()
    }

    // MARK: - Helpers

    private static func makeNote(
        kind: BrainKind,
        status: BrainStatus,
        title: String,
        topic: String,
        summary: String,
        key: String,
        conclusions: String,
        context: ModelContext
    ) -> BrainNote {
        let note = BrainNote(kind: kind, title: title, topic: topic)
        note.summary = summary
        note.keyRaw = key
        note.conclusions = conclusions
        note.status = status
        note.isDemo = true
        context.insert(note)
        return note
    }
}

private struct DemoTradeSpec {
    let dayOffset: Int
    let symbol: String
    let direction: Direction
    let entry: Double
    let stop: Double
    let take: Double
    let risk: Double
    let result: TradeResult
    let r: Double
    let structure: MarketStructure
    let poi: POIType
    let tags: [String]
    let note: String
}

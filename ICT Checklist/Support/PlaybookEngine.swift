//
//  PlaybookEngine.swift
//  ICT Checklist
//
//  Статистика плейбука и первичное наполнение сетапами из шагов чек-листа.
//

import Foundation
import SwiftData

enum PlaybookPeriod: String, CaseIterable, Identifiable {
    case days30 = "30 дней"
    case days90 = "90 дней"
    case all = "Всё время"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .days30: return 30
        case .days90: return 90
        case .all: return nil
        }
    }
}

struct PlaybookSetupStats {
    let trades: Int
    let wins: Int
    let totalR: Double
    /// Доля сделок с полностью пройденным чек-листом, 0...1.
    let discipline: Double

    var averageR: Double {
        trades > 0 ? totalR / Double(trades) : 0
    }

    var winRate: Int {
        trades > 0 ? Int((Double(wins) / Double(trades) * 100).rounded()) : 0
    }

    var disciplinePercent: Int {
        Int((discipline * 100).rounded())
    }
}

enum PlaybookEngine {
    private static let seededKey = "playbook.seeded"

    static func closedTrades(
        for setup: PlaybookSetup,
        trades: [Trade],
        scope: TradingAccount?,
        period: PlaybookPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Trade] {
        let start: Date? = {
            guard let days = period.days else { return nil }
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }()

        return trades.filter { trade in
            guard trade.setup?.persistentModelID == setup.persistentModelID else { return false }
            guard trade.result != .open else { return false }
            if let scope {
                guard trade.account?.persistentModelID == scope.persistentModelID else { return false }
            }
            if let start {
                let date = trade.closedAt ?? trade.entryDate
                return date >= start
            }
            return true
        }
    }

    static func stats(
        for setup: PlaybookSetup,
        trades: [Trade],
        scope: TradingAccount?,
        period: PlaybookPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PlaybookSetupStats {
        let list = closedTrades(
            for: setup,
            trades: trades,
            scope: scope,
            period: period,
            now: now,
            calendar: calendar
        )

        let wins = list.filter { $0.actualR > 0.05 }.count
        let totalR = list.reduce(0) { $0 + $1.actualR }
        let disciplined = list.filter { $0.plan?.isChecklistComplete ?? false }.count
        let discipline = list.isEmpty ? 0 : Double(disciplined) / Double(list.count)

        return PlaybookSetupStats(
            trades: list.count,
            wins: wins,
            totalR: totalR,
            discipline: discipline
        )
    }

    /// Три сетапа из текущих шагов чек-листа — только на самом первом запуске.
    static func seedIfNeeded(context: ModelContext, settings: AppSettings?) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }

        let existing = (try? context.fetch(FetchDescriptor<PlaybookSetup>())) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let symbols = settings?.symbols ?? ["EURUSD", "GBPUSD", "XAUUSD"]
        let typicalRR = settings?.minRR ?? 2
        let maxRiskPercent = settings?.maxRiskPercent ?? 1

        let definitions: [(name: String, session: SetupSession, marketState: String, narrative: String, pointA: String, pointB: String, zone: SetupZone, delivery: String, poi: SetupPOI, confirmation: String, entry: String, riskMode: SetupRiskMode, steps: [String])] = [
            (
                "Intraday · FVG Displacement",
                .intraday,
                "Тренд дня в одну сторону, коррекция в дисконт",
                "Цена доставляет от Key Level в дисконте к следующему FVG и IRL — сделка только внутри маршрута A→B.",
                "Key Level W1 / D1 в дисконте",
                "Следующий H4 FVG и IRL",
                .discount,
                "Strong Order Flow ещё жив, инвалидации не было",
                .fvg,
                "Закрытие H1 в зоне, замедление H1, фрактал нашей стороны",
                "Вход маркетом после закрытия H1 внутри FVG, без управления",
                .fixed,
                [
                    "Нарратив A→B записан до входа",
                    "Старший таймфрейм: D1 и H4 в одну сторону",
                    "Цена в зоне 0.5–1 импулсa (дисконт для лонга)",
                    "Strong flow жив, инвалидации нет",
                    "Inducement снят",
                    "Закрытие H1 подтвердило зону",
                    "Риск и RR известны до входа"
                ]
            ),
            (
                "Swing · A→B Rebalance",
                .swing,
                "Недельный тренд, дневной откат",
                "Недельный импульс оставил дисбаланс: ждём доставку к ребалансу диапазона и только оттуда — продолжение.",
                "D1 Key Level по недельному bias",
                "Ребаланс DR и следующий H4 FH",
                .premium,
                "Обычный Order Flow на коррекции, Strong — на продолжении",
                .snr,
                "H4 реакция на уровень, H1 закрытие в сторону сделки",
                "Вход от уровня или лимитом, стоп за инвалидацию идеи",
                .fixed,
                [
                    "Недельный bias определён",
                    "D1 дисбаланс найден",
                    "DR построен по свингам",
                    "Коррекция не инвалидировала поток",
                    "H4 подтвердил уровень",
                    "RR не ниже минимума",
                    "Стоп за отмену идеи, а не за фрактал"
                ]
            ),
            (
                "Intraday · Induced RTO",
                .intraday,
                "Диапазон с ложными пробоями",
                "Ликвидность над диапазоном снимают индюсментом, после чего цена возвращается в зону — вход только на RTO.",
                "Rejection Block на границе диапазона",
                "0.5 DR и противоположная граница",
                .any,
                "Инвалидация потока не подтверждена",
                .rb,
                "IDM снят, RTO на зоне, закрытие H1 в сторону сделки",
                "Вход лимитом от зоны RB после снятия индюсмента",
                .dynamic,
                [
                    "Ликвидность и индюсмент отмечены заранее",
                    "IDM снят до входа",
                    "Rejection Block подтверждён",
                    "Закрытие H1 в сторону сделки",
                    "RR и риск известны",
                    "Лимит стоит только у зоны"
                ]
            )
        ]

        for definition in definitions {
            let setup = PlaybookSetup(
                name: definition.name,
                symbols: symbols,
                direction: .any,
                session: definition.session,
                marketState: definition.marketState,
                narrative: definition.narrative,
                pointA: definition.pointA,
                pointB: definition.pointB,
                zone: definition.zone,
                delivery: definition.delivery,
                poi: definition.poi,
                confirmation: definition.confirmation,
                entryConditions: definition.entry,
                typicalRR: typicalRR,
                maxRiskPercent: maxRiskPercent,
                riskMode: definition.riskMode,
                checklist: definition.steps,
                note: "Сетап в логике AlexxxFX: нарратив и ключевой уровень — 80% успеха, вход — последнее."
            )
            context.insert(setup)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}

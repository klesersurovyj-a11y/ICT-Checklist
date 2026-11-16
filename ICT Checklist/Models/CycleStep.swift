//
//  CycleStep.swift
//  ICT Checklist
//

import Foundation

enum Direction: String, CaseIterable, Identifiable {
    case long = "LONG"
    case short = "SHORT"

    var id: String { rawValue }

    var expectedZone: PriceZone {
        self == .long ? .discount : .premium
    }
}

enum PriceZone: String {
    case premium = "Premium"
    case discount = "Discount"
}

enum TrendType: String, CaseIterable, Identifiable {
    case of_ = "OF"
    case sof = "SOF"

    var id: String { rawValue }

    var explain: String {
        switch self {
        case .of_:
            return "OF — поток, который доставляет цену к цели."
        case .sof:
            return "SOF — противоположный поток: цена не доставляется."
        }
    }
}

enum KeyLevelType: String, CaseIterable, Identifiable {
    case snr = "SNR"
    case fvg = "FVG"
    case fractal = "Fractal"
    case halfDR = "0.5 DR"

    var id: String { rawValue }
}

enum PointBType: String, CaseIterable, Identifiable {
    case fractal = "Fractal"
    case correctionFVG = "FVG коррекции"
    case rangeEdge = "Граница диапазона"

    var id: String { rawValue }
}

enum CycleResult: String {
    case draft
    case entry
    case stopped
}

enum TradeResult: String {
    case open = "OPEN"
    case tp = "TP"
    case sl = "SL"
    case be = "BE"
}

enum StepGroup: Int, CaseIterable, Identifiable {
    case news
    case risk
    case ofsof
    case trend
    case dr
    case pd
    case kl
    case a
    case b
    case entry

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .news: return "NEWS"
        case .risk: return "RISK"
        case .ofsof: return "OF/SOF"
        case .trend: return "TREND"
        case .dr: return "DR"
        case .pd: return "P/D"
        case .kl: return "KL"
        case .a: return "A"
        case .b: return "B"
        case .entry: return "ENTRY"
        }
    }
}

enum ConfirmationKey: String, CaseIterable, Identifiable {
    case testA
    case reaction
    case slowdown
    case fractals
    case snr
    case test

    var id: String { rawValue }

    var title: String {
        switch self {
        case .testA: return "Тест Point A D1"
        case .reaction: return "Реакция внутри A H4"
        case .slowdown: return "Замедление цены H1"
        case .fractals: return "Фракталы нашей стороны H1"
        case .snr: return "Подтверждение SNR"
        case .test: return "Финальный тест перед входом"
        }
    }

    var subtitle: String {
        switch self {
        case .testA: return "Цена протестировала Point A"
        case .reaction: return "Реакция внутри зоны A на H4"
        case .slowdown: return "Цена замедлилась на H1"
        case .fractals: return "Фракталы показывают интерес нашей стороны"
        case .snr: return "SNR дал подтверждение"
        case .test: return "SNR протестирован — можно входить"
        }
    }
}

enum CycleStep: Int, CaseIterable, Identifiable {
    case news = 0
    case risk
    case ofsof
    case trendW1
    case lastDR
    case premiumDiscount
    case keyLevels
    case keyLevelToPointA
    case pointA
    case pointB
    case testA
    case reaction
    case slowdown
    case fractals
    case snr
    case test
    case symbol
    case rr
    case entry

    var id: Int { rawValue }

    var number: Int { rawValue + 1 }

    static var total: Int { allCases.count }

    var group: StepGroup {
        switch self {
        case .news: return .news
        case .risk: return .risk
        case .ofsof: return .ofsof
        case .trendW1: return .trend
        case .lastDR: return .dr
        case .premiumDiscount: return .pd
        case .keyLevels: return .kl
        case .keyLevelToPointA, .pointA: return .a
        case .pointB: return .b
        case .testA, .reaction, .slowdown, .fractals, .snr, .test, .symbol, .rr, .entry: return .entry
        }
    }

    var title: String {
        switch self {
        case .news: return "News"
        case .risk: return "Risk"
        case .ofsof: return "OF / SOF"
        case .trendW1: return "Trend W1"
        case .lastDR: return "Last DR W1"
        case .premiumDiscount: return "Premium / Discount"
        case .keyLevels: return "Key Levels W1"
        case .keyLevelToPointA: return "Key Level → Point A"
        case .pointA: return "Point A D1"
        case .pointB: return "Point B D1"
        case .testA: return "Тест Point A"
        case .reaction: return "Реакция H4"
        case .slowdown: return "Замедление H1"
        case .fractals: return "Фракталы H1"
        case .snr: return "SNR"
        case .test: return "Финальный тест"
        case .symbol: return "Символ"
        case .rr: return "RR-проверка"
        case .entry: return "Entry"
        }
    }

    var subtitle: String {
        switch self {
        case .news: return "EUR · GBP · USD — что важно сегодня"
        case .risk: return "Ступень Risk Ladder и риск на сделку"
        case .ofsof: return "Характер недельного тренда"
        case .trendW1: return "Направление по недельному графику"
        case .lastDR: return "Последний сформированный актуальный DR"
        case .premiumDiscount: return "0.5 DR — рабочая зона для входа"
        case .keyLevels: return "Актуальные уровни в рабочей зоне"
        case .keyLevelToPointA: return "Начинаем с ближайшего актуального KL"
        case .pointA: return "SNR + нарушение OF + Fractal"
        case .pointB: return "Ближайший подходящий B сразу после A"
        case .testA: return "Цена протестировала Point A D1"
        case .reaction: return "Реакция внутри A H4"
        case .slowdown: return "Замедление цены H1"
        case .fractals: return "Фракталы интереса нашей стороны H1"
        case .snr: return "Подтверждение от SNR"
        case .test: return "SNR протестирован — финальный вход"
        case .symbol: return "Инструмент для входа"
        case .rr: return "Считаем RR и сравниваем с минимумом"
        case .entry: return "Вход по сценарию, без управления"
        }
    }

    var confirmationKey: ConfirmationKey? {
        switch self {
        case .testA: return .testA
        case .reaction: return .reaction
        case .slowdown: return .slowdown
        case .fractals: return .fractals
        case .snr: return .snr
        case .test: return .test
        default: return nil
        }
    }

    /// Index of this step on the summary route: 19:00 → NEWS → … → ENTRY → SL / TP.
    var routeIndex: Int {
        switch self {
        case .news: return 1
        case .risk: return 2
        case .ofsof: return 3
        case .trendW1: return 4
        case .lastDR: return 5
        case .premiumDiscount: return 6
        case .keyLevels: return 7
        case .keyLevelToPointA, .pointA: return 8
        case .pointB: return 9
        case .testA: return 10
        case .reaction: return 11
        case .slowdown: return 12
        case .fractals: return 13
        case .snr: return 14
        case .test: return 15
        case .symbol, .rr: return 16
        case .entry: return 17
        }
    }
}

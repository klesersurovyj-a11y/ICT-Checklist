//
//  MarketBehavior.swift
//  ICT Checklist
//
//  Классификация сделок для раздела Market Behavior Analyzer.
//

import Foundation

/// Рыночная структура, в которой открывалась сделка.
enum MarketStructure: String, CaseIterable, Identifiable {
    case trend = "Trend"
    case reversal = "Reversal"
    case correction = "Correction"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .trend:
            return "Продолжение потока OF"
        case .reversal:
            return "Смена потока — SOF"
        case .correction:
            return "Вход против недельного потока"
        }
    }

    var systemImage: String {
        switch self {
        case .trend:
            return "arrow.up.right"
        case .reversal:
            return "arrow.triangle.2.circlepath"
        case .correction:
            return "arrow.down.right"
        }
    }
}

/// Тип точки интереса (POI), от которой взят вход.
enum POIType: String, CaseIterable, Identifiable {
    case fvg = "FVG"
    case orderBlock = "OB"
    case snr = "SNR"
    case fractal = "Фрактал"
    case equilibrium = "0.5 DR"
    case rangeEdge = "Граница диапазона"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .fvg:
            return "Fair Value Gap"
        case .orderBlock:
            return "Order Block"
        case .snr:
            return "Support / Resistance"
        case .fractal:
            return "Фрактал структуры"
        case .equilibrium:
            return "Равновесие диапазона"
        case .rangeEdge:
            return "Край диапазона"
        }
    }

    var systemImage: String {
        switch self {
        case .fvg:
            return "rectangle.split.3x1"
        case .orderBlock:
            return "square.stack.3d.down.right"
        case .snr:
            return "line.horizontal.3"
        case .fractal:
            return "point.3.filled.connected.trianglepath.dotted"
        case .equilibrium:
            return "equal"
        case .rangeEdge:
            return "arrow.left.and.right"
        }
    }
}

/// Сессия, в которую открыта сделка. Границы заданы по UTC.
enum MarketSession: String, CaseIterable, Identifiable {
    case asia = "Азия"
    case london = "Лондон"
    case newYork = "Нью-Йорк"
    case lateNewYork = "Поздний NY"
    case offHours = "Вне сессий"

    var id: String { rawValue }

    init(hourUTC: Int) {
        switch hourUTC {
        case 0..<7:
            self = .asia
        case 7..<12:
            self = .london
        case 12..<17:
            self = .newYork
        case 17..<21:
            self = .lateNewYork
        default:
            self = .offHours
        }
    }

    var timeRange: String {
        switch self {
        case .asia:
            return "00:00–07:00 UTC"
        case .london:
            return "07:00–12:00 UTC"
        case .newYork:
            return "12:00–17:00 UTC"
        case .lateNewYork:
            return "17:00–21:00 UTC"
        case .offHours:
            return "21:00–00:00 UTC"
        }
    }

    var systemImage: String {
        switch self {
        case .asia:
            return "moon.stars"
        case .london:
            return "sunrise"
        case .newYork:
            return "sun.max"
        case .lateNewYork:
            return "sunset"
        case .offHours:
            return "moon"
        }
    }
}

enum MarketBehavior {
    /// Сессии считаются в UTC, чтобы Лондон и Нью-Йорк
    /// стояли на своих местах независимо от часового пояса устройства.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func hourUTC(for trade: Trade) -> Int {
        utcCalendar.component(.hour, from: trade.entryDate)
    }

    static func session(for trade: Trade) -> MarketSession {
        MarketSession(hourUTC: hourUTC(for: trade))
    }

    /// Структура из цикла дня: SOF — смена потока, вход против недельного
    /// направления — коррекция, всё остальное — продолжение тренда.
    static func derivedStructure(for trade: Trade) -> MarketStructure? {
        guard let cycle = trade.cycle else { return nil }
        if cycle.trendType == .sof {
            return .reversal
        }
        if cycle.direction != trade.direction {
            return .correction
        }
        return .trend
    }

    static func poi(for type: KeyLevelType) -> POIType {
        switch type {
        case .snr:
            return .snr
        case .fvg:
            return .fvg
        case .fractal:
            return .fractal
        case .halfDR:
            return .equilibrium
        }
    }

    /// POI из цикла дня: рабочий Key Level, иначе тип Point B.
    static func derivedPOI(for trade: Trade) -> POIType? {
        guard let cycle = trade.cycle else { return nil }
        if let level = cycle.workingKeyLevel {
            return poi(for: level.type)
        }
        switch cycle.pointBType {
        case .fractal:
            return .fractal
        case .correctionFVG:
            return .fvg
        case .rangeEdge:
            return .rangeEdge
        }
    }
}

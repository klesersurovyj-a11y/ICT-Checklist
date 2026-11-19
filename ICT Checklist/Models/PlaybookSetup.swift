//
//  PlaybookSetup.swift
//  ICT Checklist
//
//  Сетап плейбука в логике AlexxxFX (THE EDGE): сначала нарратив A→B,
//  затем зона DR, delivery, подтверждение и только потом вход.
//

import Foundation
import SwiftData

enum SetupDirection: String, CaseIterable, Identifiable {
    case any = "ANY"
    case long = "LONG"
    case short = "SHORT"

    var id: String { rawValue }

    var tradeDirection: Direction? {
        switch self {
        case .any: return nil
        case .long: return .long
        case .short: return .short
        }
    }
}

enum SetupSession: String, CaseIterable, Identifiable {
    case intraday = "Intraday"
    case swing = "Swing"

    var id: String { rawValue }
}

enum SetupZone: String, CaseIterable, Identifiable {
    case discount = "Discount"
    case premium = "Premium"
    case any = "Любая"

    var id: String { rawValue }
}

enum SetupPOI: String, CaseIterable, Identifiable {
    case fvg = "FVG"
    case rb = "RB"
    case snr = "SNR"
    case displacement = "Displacement"

    var id: String { rawValue }
}

enum SetupRiskMode: String, CaseIterable, Identifiable {
    case fixed = "Фикс"
    case dynamic = "Дин"

    var id: String { rawValue }
}

@Model
final class PlaybookSetup {
    var name: String = ""
    var symbolsRaw: String = ""
    var directionRaw: String = SetupDirection.any.rawValue

    // MARK: Модель AlexxxFX

    var sessionRaw: String = SetupSession.intraday.rawValue
    /// Состояние рынка: тренд, диапазон, компрессия и т. п.
    var marketState: String = ""
    /// Нарратив A→B: что и куда доставляется.
    var narrative: String = ""
    var pointA: String = ""
    var pointB: String = ""
    var zoneRaw: String = SetupZone.any.rawValue
    /// Strong / True Order Flow и условие его инвалидации.
    var delivery: String = ""
    var poiRaw: String = SetupPOI.fvg.rawValue
    /// Подтверждение на младшем ТФ и индюсмент.
    var confirmation: String = ""

    var entryConditions: String = ""
    var typicalRR: Double = 3
    var maxRiskPercent: Double = 1
    var riskModeRaw: String = SetupRiskMode.fixed.rawValue

    /// Шаги чек-листа, по одному на строку.
    var checklistRaw: String = ""
    var note: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Trade.setup)
    var trades: [Trade] = []

    init(
        name: String = "",
        symbols: [String] = [],
        direction: SetupDirection = .any,
        session: SetupSession = .intraday,
        marketState: String = "",
        narrative: String = "",
        pointA: String = "",
        pointB: String = "",
        zone: SetupZone = .any,
        delivery: String = "",
        poi: SetupPOI = .fvg,
        confirmation: String = "",
        entryConditions: String = "",
        typicalRR: Double = 3,
        maxRiskPercent: Double = 1,
        riskMode: SetupRiskMode = .fixed,
        checklist: [String] = [],
        note: String = ""
    ) {
        self.name = name
        self.symbolsRaw = symbols.joined(separator: ",")
        self.directionRaw = direction.rawValue
        self.sessionRaw = session.rawValue
        self.marketState = marketState
        self.narrative = narrative
        self.pointA = pointA
        self.pointB = pointB
        self.zoneRaw = zone.rawValue
        self.delivery = delivery
        self.poiRaw = poi.rawValue
        self.confirmation = confirmation
        self.entryConditions = entryConditions
        self.typicalRR = typicalRR
        self.maxRiskPercent = maxRiskPercent
        self.riskModeRaw = riskMode.rawValue
        self.checklistRaw = checklist.joined(separator: "\n")
        self.note = note
        self.isArchived = false
        self.createdAt = .now
        self.trades = []
    }

    var direction: SetupDirection {
        get { SetupDirection(rawValue: directionRaw) ?? .any }
        set { directionRaw = newValue.rawValue }
    }

    var session: SetupSession {
        get { SetupSession(rawValue: sessionRaw) ?? .intraday }
        set { sessionRaw = newValue.rawValue }
    }

    var zone: SetupZone {
        get { SetupZone(rawValue: zoneRaw) ?? .any }
        set { zoneRaw = newValue.rawValue }
    }

    var poi: SetupPOI {
        get { SetupPOI(rawValue: poiRaw) ?? .fvg }
        set { poiRaw = newValue.rawValue }
    }

    var riskMode: SetupRiskMode {
        get { SetupRiskMode(rawValue: riskModeRaw) ?? .fixed }
        set { riskModeRaw = newValue.rawValue }
    }

    var symbols: [String] {
        get {
            symbolsRaw
                .split(whereSeparator: { $0 == "," || $0 == "·" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            symbolsRaw = newValue.joined(separator: ",")
        }
    }

    var checklistSteps: [String] {
        get {
            checklistRaw
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            checklistRaw = newValue.joined(separator: "\n")
        }
    }

    var symbolLine: String {
        let list = symbols
        return list.isEmpty ? "Все инструменты" : list.joined(separator: " · ")
    }

    /// Маршрут A → B одной строкой.
    var routeLine: String? {
        let from = pointA.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = pointB.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty || !to.isEmpty else { return nil }
        return "\(from.isEmpty ? "A" : from) → \(to.isEmpty ? "B" : to)"
    }

    var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без названия" : trimmed
    }
}

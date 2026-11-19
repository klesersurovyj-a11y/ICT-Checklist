//
//  FundMandate.swift
//  ICT Checklist
//
//  Мандат фонда: лимиты, по которым проверяется каждая сделка.
//  У мандата есть версия и дата; активна одна версия.
//

import Foundation
import SwiftData

@Model
final class FundMandate {
    var createdAt: Date = Date()
    var version: Int = 1
    var note: String = ""
    var isActive: Bool = true

    /// Риск на сделку в процентах капитала.
    var riskPerTradePercent: Double = 1
    /// Риск дня в процентах капитала.
    var riskPerDayPercent: Double = 3
    /// Риск месяца в процентах капитала.
    var riskPerMonthPercent: Double = 8
    /// Максимум сделок в день.
    var maxTradesPerDay: Int = 2
    /// Доля одного инструмента в открытом риске, проценты капитала.
    var maxInstrumentPercent: Double = 25
    /// Доля группы связанных инструментов, проценты капитала.
    var maxGroupPercent: Double = 40
    /// Целевые веса сетапов в процентах, JSON.
    var setupWeightsRaw: String = ""
    /// Ставка на один фактор (валюта), проценты капитала.
    var maxFactorPercent: Double = 50

    /// Целевые веса сетапов: имя → проценты.
    var setupWeights: [String: Double] {
        get {
            guard let data = setupWeightsRaw.data(using: .utf8),
                  let value = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            setupWeightsRaw = String(data: data, encoding: .utf8) ?? ""
        }
    }

    init(
        createdAt: Date = .now,
        version: Int = 1,
        note: String = "",
        isActive: Bool = true
    ) {
        self.createdAt = createdAt
        self.version = version
        self.note = note
        self.isActive = isActive
    }

    static func active(in mandates: [FundMandate]) -> FundMandate? {
        mandates.first { $0.isActive }
    }

    static func nextVersion(in mandates: [FundMandate]) -> Int {
        (mandates.map(\.version).max() ?? 0) + 1
    }
}

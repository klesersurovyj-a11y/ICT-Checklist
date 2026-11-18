//
//  TradeReview.swift
//  ICT Checklist
//
//  Разбор закрытой сделки: причина входа, рыночный контекст,
//  соблюдение алгоритма и причина результата.
//

import Foundation
import SwiftData

/// Насколько сделка соответствовала торговому алгоритму.
enum AlgorithmAdherence: String, CaseIterable, Identifiable {
    case unknown = "Не оценено"
    case followed = "Соблюдён"
    case partial = "Частично"
    case broken = "Нарушен"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .unknown:
            return "—"
        case .followed:
            return "Да"
        case .partial:
            return "Частично"
        case .broken:
            return "Нет"
        }
    }

    var subtitle: String {
        switch self {
        case .unknown:
            return "Разбор ещё не заполнен"
        case .followed:
            return "Вход по системе от начала до конца"
        case .partial:
            return "Часть шагов пропущена или сделана иначе"
        case .broken:
            return "Вход против правил системы"
        }
    }
}

@Model
final class TradeReview {
    var entryReason: String = ""
    var marketContext: String = ""
    var resultReason: String = ""
    var adherenceRaw: String = AlgorithmAdherence.unknown.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Trade.review)
    var trade: Trade?

    init(trade: Trade? = nil) {
        self.entryReason = ""
        self.marketContext = ""
        self.resultReason = ""
        self.adherenceRaw = AlgorithmAdherence.unknown.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.trade = trade
    }

    var adherence: AlgorithmAdherence {
        get { AlgorithmAdherence(rawValue: adherenceRaw) ?? .unknown }
        set {
            adherenceRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var isFilled: Bool {
        !entryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !marketContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !resultReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || adherence != .unknown
    }
}

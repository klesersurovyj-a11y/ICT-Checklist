//
//  LossReview.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Разбор убыточной сделки: почему вошли и что произошло,
/// плюс прикреплённые похожие сделки.
@Model
final class LossReview {
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Trade.lossReview)
    var trade: Trade?

    @Relationship(deleteRule: .nullify, inverse: \Trade.similarReviews)
    var similarTrades: [Trade] = []

    init(note: String = "", trade: Trade? = nil) {
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
        self.trade = trade
        self.similarTrades = []
    }

    var similar: [Trade] {
        similarTrades.sorted { $0.tradingDay > $1.tradingDay }
    }

    func attach(_ trade: Trade) {
        guard !similarTrades.contains(where: { $0.persistentModelID == trade.persistentModelID }) else { return }
        similarTrades.append(trade)
        updatedAt = .now
    }

    func detach(_ trade: Trade) {
        similarTrades = similarTrades.filter {
            $0.persistentModelID != trade.persistentModelID
        }
        updatedAt = .now
    }
}

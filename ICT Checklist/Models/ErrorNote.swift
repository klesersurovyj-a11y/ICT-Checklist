//
//  ErrorNote.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Состояние ошибки: ждём результат, отработали или она повторилась.
enum ErrorStatus: String, CaseIterable, Identifiable {
    case awaiting = "Жду результат"
    case fixed = "Отработано"
    case repeated = "Повторилось"

    var id: String { rawValue }

    var isResolved: Bool { self == .fixed }
}

/// Ошибка трейдера: что случилось, каких сделок она касается
/// и какой результат ждём после отработки.
@Model
final class ErrorNote {
    var title: String = ""
    var text: String = ""
    var statusRaw: String = ErrorStatus.awaiting.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Trade.errorNotes)
    var trades: [Trade] = []

    @Relationship(deleteRule: .cascade, inverse: \ErrorShot.note)
    var shots: [ErrorShot] = []

    init(title: String = "", text: String = "", status: ErrorStatus = .awaiting) {
        self.title = title
        self.text = text
        self.statusRaw = status.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.trades = []
        self.shots = []
    }

    var sortedShots: [ErrorShot] {
        shots.sorted { $0.createdAt < $1.createdAt }
    }

    var status: ErrorStatus {
        get { ErrorStatus(rawValue: statusRaw) ?? .awaiting }
        set { statusRaw = newValue.rawValue }
    }

    var sortedTrades: [Trade] {
        trades.sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

    var closedCount: Int {
        trades.filter { $0.result != .open }.count
    }

    var totalR: Double {
        trades.reduce(0) { $0 + $1.actualR }
    }

    func attach(_ trade: Trade) {
        guard !trades.contains(where: { $0.persistentModelID == trade.persistentModelID }) else { return }
        trades.append(trade)
        updatedAt = .now
    }

    func detach(_ trade: Trade) {
        trades = trades.filter { $0.persistentModelID != trade.persistentModelID }
        updatedAt = .now
    }
}

/// Скриншот терминала, прикреплённый к ошибке.
@Model
final class ErrorShot {
    @Attribute(.externalStorage) var imageData: Data? = nil
    var createdAt: Date = Date()
    var note: ErrorNote?

    init(imageData: Data? = nil, createdAt: Date = .now) {
        self.imageData = imageData
        self.createdAt = createdAt
        self.note = nil
    }
}

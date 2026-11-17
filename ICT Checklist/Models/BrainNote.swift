//
//  BrainNote.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Тип записи Second Brain: ключевая заметка или формула алгоритма работы.
enum BrainKind: String, CaseIterable, Identifiable {
    case keyNote = "Ключевая заметка"
    case formula = "Формула"

    var id: String { rawValue }

    var short: String {
        switch self {
        case .keyNote: return "Заметка"
        case .formula: return "Формула"
        }
    }

    var icon: String {
        switch self {
        case .keyNote: return "bookmark.fill"
        case .formula: return "arrow.triangle.branch"
        }
    }

    var keyTitle: String {
        switch self {
        case .keyNote: return "Ключ"
        case .formula: return "Ключевые функции"
        }
    }

    var placeholderTitle: String {
        switch self {
        case .keyNote: return "Например: Однопоточные данные PMI"
        case .formula: return "Например: Схождение двух новостей"
        }
    }
}

/// Запись базы знаний: описание, ключ, преимущества, схема,
/// примеры графиков, выводы и прикреплённые сделки.
@Model
final class BrainNote {
    var kindRaw: String = BrainKind.keyNote.rawValue
    var title: String = ""
    var topic: String = ""
    var summary: String = ""
    /// Пункты ключа: по одному на строку.
    var keyRaw: String = ""
    var benefits: String = ""
    var schematic: String = ""
    var chartExamples: String = ""
    var conclusions: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var popularity: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \BrainShot.note)
    var photos: [BrainShot] = []

    @Relationship(deleteRule: .nullify, inverse: \Trade.brainNotes)
    var trades: [Trade] = []

    init(kind: BrainKind = .keyNote, title: String = "", topic: String = "") {
        self.kindRaw = kind.rawValue
        self.title = title
        self.topic = topic
        self.summary = ""
        self.keyRaw = ""
        self.benefits = ""
        self.schematic = ""
        self.chartExamples = ""
        self.conclusions = ""
        self.createdAt = .now
        self.updatedAt = .now
        self.popularity = 0
        self.photos = []
        self.trades = []
    }

    var kind: BrainKind {
        get { BrainKind(rawValue: kindRaw) ?? .keyNote }
        set { kindRaw = newValue.rawValue }
    }

    var keyPoints: [String] {
        keyRaw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var displayTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    var sortedPhotos: [BrainShot] {
        photos.sorted { $0.createdAt < $1.createdAt }
    }

    var sortedTrades: [Trade] {
        trades.sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
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

/// Скриншот или фото, прикреплённое к записи Second Brain.
@Model
final class BrainShot {
    @Attribute(.externalStorage) var imageData: Data? = nil
    var createdAt: Date = Date()
    var note: BrainNote?

    init(imageData: Data? = nil, createdAt: Date = .now) {
        self.imageData = imageData
        self.createdAt = createdAt
        self.note = nil
    }
}

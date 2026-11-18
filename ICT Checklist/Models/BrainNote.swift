//
//  BrainNote.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Тип записи базы знаний трейдера.
enum BrainKind: String, CaseIterable, Identifiable {
    case observation = "Наблюдение"
    case hypothesis = "Гипотеза"
    case research = "Исследование"
    case rule = "Правило алгоритма"
    case pattern = "Закономерность"
    case keyNote = "Ключевая заметка"
    case formula = "Формула"

    var id: String { rawValue }

    var short: String {
        switch self {
        case .observation: return "Наблюдение"
        case .hypothesis: return "Гипотеза"
        case .research: return "Исследование"
        case .rule: return "Правило"
        case .pattern: return "Закономерность"
        case .keyNote: return "Заметка"
        case .formula: return "Формула"
        }
    }

    var icon: String {
        switch self {
        case .observation: return "eye"
        case .hypothesis: return "lightbulb"
        case .research: return "magnifyingglass"
        case .rule: return "checklist"
        case .pattern: return "chart.xyaxis.line"
        case .keyNote: return "bookmark.fill"
        case .formula: return "arrow.triangle.branch"
        }
    }

    var keyTitle: String {
        switch self {
        case .observation: return "Признаки"
        case .hypothesis: return "Что проверить"
        case .research: return "Что исследовал"
        case .rule: return "Правила"
        case .pattern: return "Как проявляется"
        case .keyNote: return "Ключ"
        case .formula: return "Ключевые функции"
        }
    }

    var placeholderTitle: String {
        switch self {
        case .observation: return "Например: после снятия азиатского лоу цена идёт к PDH"
        case .hypothesis: return "Например: вход только после реакции H4 повышает winrate"
        case .research: return "Например: поведение EURUSD в первые 30 минут Лондона"
        case .rule: return "Например: риск не выше ступени, вход только после теста SNR"
        case .pattern: return "Например: три TP подряд в лондонскую сессию"
        case .keyNote: return "Например: Однопоточные данные PMI"
        case .formula: return "Например: Схождение двух новостей"
        }
    }

    /// Для этих типов важно, проверена ли запись на практике.
    var usesStatus: Bool {
        switch self {
        case .keyNote, .formula:
            return false
        default:
            return true
        }
    }
}

/// Статус проверки наблюдения, гипотезы или правила.
enum BrainStatus: String, CaseIterable, Identifiable {
    case idea = "Идея"
    case testing = "Проверяю"
    case confirmed = "Подтверждено"
    case rejected = "Опровергнуто"

    var id: String { rawValue }
}

/// Запись базы знаний: описание, ключ, преимущества, схема,
/// примеры графиков, выводы и прикреплённые сделки.
@Model
final class BrainNote {
    var kindRaw: String = BrainKind.keyNote.rawValue
    var statusRaw: String = BrainStatus.idea.rawValue
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
        self.statusRaw = BrainStatus.idea.rawValue
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

    var status: BrainStatus {
        get { BrainStatus(rawValue: statusRaw) ?? .idea }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
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

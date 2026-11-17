//
//  JournalEntry.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Настроение торгового дня.
enum JournalMood: String, CaseIterable, Identifiable {
    case calm = "Спокойно"
    case confident = "Уверенно"
    case doubtful = "Сомневался"
    case rushed = "Спешил"

    var id: String { rawValue }
}

/// Запись дневника трейдера за один торговый день.
@Model
final class JournalEntry {
    var day: Date = Date()
    var moodRaw: String = JournalMood.calm.rawValue
    var note: String = ""
    var improve: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        day: Date = Calendar.current.startOfDay(for: .now),
        mood: JournalMood = .calm,
        note: String = "",
        improve: String = ""
    ) {
        self.day = day
        self.moodRaw = mood.rawValue
        self.note = note
        self.improve = improve
        self.createdAt = .now
        self.updatedAt = .now
    }

    var mood: JournalMood {
        get { JournalMood(rawValue: moodRaw) ?? .calm }
        set { moodRaw = newValue.rawValue }
    }

    /// Первая строка записи — для списка прошлых дней.
    var preview: String {
        let source = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? improve
            : note
        let line = source
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

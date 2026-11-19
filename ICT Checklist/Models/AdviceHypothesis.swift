//
//  AdviceHypothesis.swift
//  ICT Checklist
//
//  Совет ассистента как проверяемая гипотеза: гипотеза, метрика,
//  срок проверки в сделках и результат.
//

import Foundation
import SwiftData

enum AdviceStatus: String, CaseIterable, Identifiable {
    case draft = "Черновик"
    case testing = "Проверяется"
    case confirmed = "Подтвердилось"
    case rejected = "Не подтвердилось"

    var id: String { rawValue }
}

@Model
final class AdviceHypothesis {
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Гипотеза одной фразой: что должно измениться.
    var title: String = ""
    /// Вопрос, на который отвечал ассистент.
    var question: String = ""
    /// Ответ ассистента, сохранённый целиком.
    var answer: String = ""
    /// Метрика проверки: что именно измеряем.
    var metric: String = ""
    /// Через сколько закрытых сделок проверить гипотезу.
    var checkAfterTrades: Int = 5
    var statusRaw: String = AdviceStatus.draft.rawValue
    var checkedAt: Date? = nil
    /// Итог проверки в R: сложится из сделок, закрытых после создания.
    var note: String = ""

    init(question: String = "", answer: String = "") {
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.title = ""
        self.question = question
        self.answer = answer
        self.metric = ""
        self.checkAfterTrades = 5
        self.statusRaw = AdviceStatus.draft.rawValue
        self.checkedAt = nil
        self.note = ""
    }

    var status: AdviceStatus {
        get { AdviceStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    /// Совет без гипотезы и метрики остаётся черновиком.
    var isComplete: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && checkAfterTrades > 0
    }
}

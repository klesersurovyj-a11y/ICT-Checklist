//
//  WeekPlan.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// План торговой недели: тема, цель по R и сценарии, которые хочется отработать.
@Model
final class WeekPlan {
    var weekStart: Date = Date()
    var theme: String = ""
    var targetR: Double = 6
    /// Итог недели одной заметкой: что сработало, что нет, что менять.
    var review: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WeekScenario.plan)
    var scenarios: [WeekScenario] = []

    init(weekStart: Date = Date(), theme: String = "", targetR: Double = 6) {
        self.weekStart = weekStart
        self.theme = theme
        self.targetR = targetR
        self.review = ""
        self.createdAt = .now
        self.updatedAt = .now
        self.scenarios = []
    }

    var sortedScenarios: [WeekScenario] {
        scenarios.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.createdAt < $1.createdAt
        }
    }
}

/// Один сценарий недели с заметкой.
@Model
final class WeekScenario {
    var title: String = ""
    var note: String = ""
    var position: Int = 0
    var createdAt: Date = Date()
    var plan: WeekPlan?

    init(title: String = "", note: String = "", position: Int = 0) {
        self.title = title
        self.note = note
        self.position = position
        self.createdAt = .now
        self.plan = nil
    }
}

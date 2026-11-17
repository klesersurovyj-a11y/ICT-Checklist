//
//  SystemBlueprint.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Один этап торговой системы: что проверяю и по какому правилу.
struct SystemStage: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var rule: String
    var isEnabled: Bool = true

    static func newStage() -> SystemStage {
        SystemStage(
            id: UUID().uuidString,
            title: "",
            detail: "",
            rule: ""
        )
    }

    /// Костяк TDA + Risk: от недельного контекста до входа с готовым риском.
    static let tdaPreset: [SystemStage] = [
        SystemStage(
            id: "w1-context",
            title: "Контекст W1",
            detail: "Недельный тренд и последний DR",
            rule: "OF/SOF на W1, последний актуальный DR, направление дня"
        ),
        SystemStage(
            id: "draw-on-liquidity",
            title: "Draw on Liquidity",
            detail: "Куда доставляется цена",
            rule: "Цель — ближайшая незакрытая ликвидность"
        ),
        SystemStage(
            id: "key-level",
            title: "Key level / PD array",
            detail: "Рабочий уровень в зоне",
            rule: "Ключевой уровень в premium или discount относительно 0.5 DR"
        ),
        SystemStage(
            id: "scenario",
            title: "Point A → Point B",
            detail: "Сценарий от уровня",
            rule: "A D1 — SNR + нарушение OF + фрактал, B — первый коррекционный уровень"
        ),
        SystemStage(
            id: "ltf-confirmation",
            title: "LTF подтверждение",
            detail: "Тест, реакция, замедление, SNR",
            rule: "Тест A, реакция H4, замедление H1, фракталы, SNR, финальный тест"
        ),
        SystemStage(
            id: "entry",
            title: "Вход и RR",
            detail: "Вход по сценарию без управления",
            rule: "RR не ниже минимума, стоп за структурой, сделка по плану"
        )
    ]
}

/// Собранная торговая система: этапы, риск-модель и лимиты.
@Model
final class SystemBlueprint {
    var name: String = "TDA + Risk"
    var stagesData: Data = Data()

    var minRR: Double = 2
    var ladder1: Double = 12
    var ladder2: Double = 25
    var ladder3: Double = 50
    var maxTradesPerDay: Int = 2
    var maxDailyLossR: Double = 2
    var dailyLimitsEnabled: Bool = true

    var updatedAt: Date = Date()

    init(name: String = "TDA + Risk") {
        self.name = name
        stagesData = (try? JSONEncoder().encode(SystemStage.tdaPreset)) ?? Data()
    }

    var stages: [SystemStage] {
        get {
            guard
                let decoded = try? JSONDecoder().decode([SystemStage].self, from: stagesData),
                !decoded.isEmpty
            else {
                return SystemStage.tdaPreset
            }
            return decoded
        }
        set {
            stagesData = (try? JSONEncoder().encode(newValue)) ?? stagesData
        }
    }

    /// Система одна: берём существующую или создаём костяк TDA + Risk.
    static func loadOrCreate(context: ModelContext) -> SystemBlueprint {
        let existing = (try? context.fetch(FetchDescriptor<SystemBlueprint>())) ?? []
        if let first = existing.first { return first }

        let created = SystemBlueprint()
        context.insert(created)
        try? context.save()
        return created
    }
}

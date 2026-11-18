//
//  TradePlan.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Итог плана. Планы без итога остаются в статусе `pending`.
enum PlanResult: String, CaseIterable, Identifiable {
    case pending = "Без итога"
    case win = "Win"
    case loss = "Loss"
    case be = "BE"
    case skip = "Skip"
    case noTrade = "No trade"

    var id: String { rawValue }

    var isDecided: Bool { self != .pending }
}

/// Пункты системы, которые проверяются в плане перед входом.
enum PlanCheck: String, CaseIterable, Identifiable {
    case news
    case risk
    case flow
    case trend
    case drawRange
    case zone
    case keyLevel
    case pointA
    case pointB
    case confirmations
    case rr
    case limits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .news: return "Новости изучены"
        case .risk: return "Ступень и риск по системе"
        case .flow: return "OF / SOF определён"
        case .trend: return "Тренд W1 учтён"
        case .drawRange: return "Последний DR взят"
        case .zone: return "Зона Premium / Discount соответствует"
        case .keyLevel: return "Key Level актуален"
        case .pointA: return "Point A валиден"
        case .pointB: return "Point B валиден"
        case .confirmations: return "Подтверждения отмечены"
        case .rr: return "RR не ниже минимума"
        case .limits: return "Лимиты дня не нарушены"
        }
    }
}

/// План торгового дня: идея, план A / B / адаптация, чек-лист системы,
/// заметки, скриншоты и прикреплённые сделки.
@Model
final class TradePlan {
    var day: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var title: String = ""
    var symbol: String = "EURUSD"
    var directionRaw: String = Direction.long.rawValue
    var resultRaw: String = PlanResult.pending.rawValue

    var thesis: String = ""
    var planA: String = ""
    var planB: String = ""
    var adaptation: String = ""
    var note: String = ""

    // План A по аспектам.
    var aBias: String = ""
    var aBackground: String = ""
    var aWhat: String = ""
    var aEntry: String = ""
    var aTarget: String = ""
    var aInvalidation: String = ""

    // План B по аспектам.
    var bBias: String = ""
    var bBackground: String = ""
    var bWhat: String = ""
    var bEntry: String = ""
    var bTarget: String = ""
    var bInvalidation: String = ""

    // Пост-сессионный разбор.
    var chartTF: String = ""
    var conclusions: String = ""
    var narrative: String = ""

    var checklistRaw: String = ""

    /// План загружен демо-базой и удаляется одной кнопкой в настройках.
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \PlanPhoto.plan)
    var photos: [PlanPhoto] = []

    @Relationship(deleteRule: .nullify, inverse: \Trade.plan)
    var trades: [Trade] = []

    init(
        day: Date = Calendar.current.startOfDay(for: .now),
        symbol: String = "EURUSD",
        direction: Direction = .long
    ) {
        self.day = day
        self.createdAt = .now
        self.updatedAt = .now
        self.title = ""
        self.symbol = symbol
        self.directionRaw = direction.rawValue
        self.resultRaw = PlanResult.pending.rawValue
        self.thesis = ""
        self.planA = ""
        self.planB = ""
        self.adaptation = ""
        self.note = ""
        self.aBias = ""
        self.aBackground = ""
        self.aWhat = ""
        self.aEntry = ""
        self.aTarget = ""
        self.aInvalidation = ""
        self.bBias = ""
        self.bBackground = ""
        self.bWhat = ""
        self.bEntry = ""
        self.bTarget = ""
        self.bInvalidation = ""
        self.chartTF = ""
        self.conclusions = ""
        self.narrative = ""
        self.checklistRaw = ""
        self.isDemo = false
        self.photos = []
        self.trades = []
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .long }
        set { directionRaw = newValue.rawValue }
    }

    var result: PlanResult {
        get { PlanResult(rawValue: resultRaw) ?? .pending }
        set { resultRaw = newValue.rawValue }
    }

    var checkedKeys: Set<PlanCheck> {
        get {
            let keys = checklistRaw
                .split(separator: ",")
                .map(String.init)
                .compactMap { PlanCheck(rawValue: $0) }
            return Set(keys)
        }
        set {
            checklistRaw = newValue.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    var checkedCount: Int { checkedKeys.count }

    var isChecklistComplete: Bool { checkedKeys.count == PlanCheck.allCases.count }

    var hasPlanA: Bool { !planA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasPlanB: Bool { !planB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasAdaptation: Bool { !adaptation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var sortedPhotos: [PlanPhoto] {
        photos.sorted { $0.createdAt < $1.createdAt }
    }

    func toggle(_ check: PlanCheck) {
        var keys = checkedKeys
        if keys.contains(check) {
            keys.remove(check)
        } else {
            keys.insert(check)
        }
        checkedKeys = keys
        updatedAt = .now
    }
}

/// Скриншот плана. Хранится в базе и синхронизируется через iCloud.
@Model
final class PlanPhoto {
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    var plan: TradePlan?

    init(imageData: Data? = nil, createdAt: Date = .now) {
        self.imageData = imageData
        self.createdAt = createdAt
        self.plan = nil
    }
}

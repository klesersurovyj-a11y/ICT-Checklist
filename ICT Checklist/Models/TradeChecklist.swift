//
//  TradeChecklist.swift
//  ICT Checklist
//
//  Чек-лист сделки: проверка конкретного входа, а не ежедневный ритуал.
//

import Foundation

enum TradeCheck: String, CaseIterable, Identifiable {
    case context
    case narrative
    case range
    case poi
    case delivery
    case validation
    case risk
    case rr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .context: return "Контекст и новости"
        case .narrative: return "Нарратив A → B"
        case .range: return "DR и рабочая зона"
        case .poi: return "POI валиден"
        case .delivery: return "Delivery и поток"
        case .validation: return "Валидация на X-1"
        case .risk: return "Риск по ступени"
        case .rr: return "RR выше минимума"
        }
    }

    var subtitle: String {
        switch self {
        case .context:
            return "Сверил календарь и новости по валютам сделки"
        case .narrative:
            return "Точка A и точка B определены, вход внутри маршрута"
        case .range:
            return "Диапазон построен, вход из discount для лонга или из premium для шорта"
        case .poi:
            return "Уровень или зона не инвалидированы потоком"
        case .delivery:
            return "Понял, доставляется ли цена к цели или это откат"
        case .validation:
            return "Младший таймфрейм подтвердил вход, а не сам уровень"
        case .risk:
            return "Риск взят со ступени лэддера, лимиты дня не нарушены"
        case .rr:
            return "RR посчитан до входа и не ниже минимума"
        }
    }
}

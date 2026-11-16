//
//  MonthlyGoal.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Цель по суммарному R на конкретный месяц. Хранится по одному месяцу,
/// чтобы прошлые месяцы показывали цель, которая была поставлена тогда.
@Model
final class MonthlyGoal {
    var monthStart: Date = Date()
    var targetR: Double = 10

    init(monthStart: Date = Date(), targetR: Double = 10) {
        self.monthStart = monthStart
        self.targetR = targetR
    }
}

//
//  SystemVersion.swift
//  ICT Checklist
//
//  Версия торговых правил: что меняется, гипотеза, метрика и срок проверки.
//

import Foundation
import SwiftData

@Model
final class SystemVersion {
    var createdAt: Date = Date()
    var version: Int = 1
    /// Что именно меняется в правилах.
    var change: String = ""
    /// Гипотеза изменения.
    var hypothesis: String = ""
    /// Метрика проверки.
    var metric: String = ""
    /// Через сколько закрытых сделок проверять.
    var checkAfterTrades: Int = 20
    /// Причина записи: зачем меняли или откатывали.
    var note: String = ""
    var isActive: Bool = false

    init(
        version: Int,
        createdAt: Date = .now,
        change: String = "",
        hypothesis: String = "",
        metric: String = "",
        checkAfterTrades: Int = 20,
        note: String = "",
        isActive: Bool = false
    ) {
        self.createdAt = createdAt
        self.version = version
        self.change = change
        self.hypothesis = hypothesis
        self.metric = metric
        self.checkAfterTrades = max(checkAfterTrades, 1)
        self.note = note
        self.isActive = isActive
    }
}

//
//  TrainingRun.swift
//  ICT Checklist
//
//  Результат тренировки входа: дата, символ, оценка и что бы дало по R.
//

import Foundation
import SwiftData

@Model
final class TrainingRun {
    var date: Date = Date()
    var symbol: String = ""
    var score: Int = 0
    var correctSteps: Int = 0
    var totalSteps: Int = 5
    var wouldBeR: Double = 0
    /// Краткая расшифровка решений: «Риск верный; Цель — неверно».
    var summary: String = ""

    init(
        date: Date = .now,
        symbol: String = "",
        score: Int = 0,
        correctSteps: Int = 0,
        totalSteps: Int = 5,
        wouldBeR: Double = 0,
        summary: String = ""
    ) {
        self.date = date
        self.symbol = symbol
        self.score = score
        self.correctSteps = correctSteps
        self.totalSteps = totalSteps
        self.wouldBeR = wouldBeR
        self.summary = summary
    }
}

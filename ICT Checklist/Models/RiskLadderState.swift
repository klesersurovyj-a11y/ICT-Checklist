//
//  RiskLadderState.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class RiskLadderState {
    var stepIndex: Int = 0
    var accumulatedR: Double = 0
    var updatedAt: Date = Date()

    init(stepIndex: Int = 0, accumulatedR: Double = 0) {
        self.stepIndex = stepIndex
        self.accumulatedR = accumulatedR
        self.updatedAt = .now
    }
}

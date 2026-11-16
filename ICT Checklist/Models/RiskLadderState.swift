//
//  RiskLadderState.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class RiskLadderState {
    var stepIndex: Int
    var accumulatedR: Double
    var updatedAt: Date

    init(stepIndex: Int = 0, accumulatedR: Double = 0) {
        self.stepIndex = stepIndex
        self.accumulatedR = accumulatedR
        self.updatedAt = .now
    }
}

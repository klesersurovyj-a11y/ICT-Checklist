//
//  ScenarioRecord.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class ScenarioRecord {
    var pointAPrice: Double = 0
    var pointADepth: Double = 0
    var pointBPrice: Double? = nil
    var pointBTypeRaw: String = PointBType.fractal.rawValue
    var pointAValid: Bool = true
    var pointBValid: Bool = true
    var isCurrent: Bool = false
    var createdAt: Date = Date()
    var cycle: TradingCycle?

    init(pointAPrice: Double,
         pointADepth: Double = 0,
         pointAValid: Bool = true) {
        self.pointAPrice = pointAPrice
        self.pointADepth = pointADepth
        self.pointBPrice = nil
        self.pointBTypeRaw = PointBType.fractal.rawValue
        self.pointAValid = pointAValid
        self.pointBValid = true
        self.isCurrent = false
        self.createdAt = .now
        self.cycle = nil
    }

    var pointBType: PointBType {
        get { PointBType(rawValue: pointBTypeRaw) ?? .fractal }
        set { pointBTypeRaw = newValue.rawValue }
    }

    var isSelectable: Bool {
        pointAValid && pointBValid
    }
}

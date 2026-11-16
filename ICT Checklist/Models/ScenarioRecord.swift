//
//  ScenarioRecord.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class ScenarioRecord {
    var pointAPrice: Double
    var pointADepth: Double
    var pointBPrice: Double?
    var pointBTypeRaw: String
    var pointAValid: Bool
    var pointBValid: Bool
    var isCurrent: Bool
    var createdAt: Date
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

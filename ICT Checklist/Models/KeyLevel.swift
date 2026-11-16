//
//  KeyLevel.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class KeyLevel {
    var typeRaw: String
    var price: Double
    var note: String
    var absorbed: Bool
    var isWorking: Bool
    var createdAt: Date
    var cycle: TradingCycle?

    init(type: KeyLevelType,
         price: Double,
         note: String = "",
         absorbed: Bool = false,
         isWorking: Bool = false) {
        self.typeRaw = type.rawValue
        self.price = price
        self.note = note
        self.absorbed = absorbed
        self.isWorking = isWorking
        self.createdAt = .now
        self.cycle = nil
    }

    var type: KeyLevelType {
        get { KeyLevelType(rawValue: typeRaw) ?? .snr }
        set { typeRaw = newValue.rawValue }
    }
}

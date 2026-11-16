//
//  KeyLevel.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class KeyLevel {
    var typeRaw: String = KeyLevelType.snr.rawValue
    var price: Double = 0
    var note: String = ""
    var absorbed: Bool = false
    var isWorking: Bool = false
    var createdAt: Date = Date()
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

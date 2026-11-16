//
//  AppSettings.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var symbolsRaw: String
    var minRR: Double
    var ladder1: Double
    var ladder2: Double
    var ladder3: Double
    var cycleStartHour: Int
    var cycleStartMinute: Int = 0
    var cycleEndHour: Int
    var cycleEndMinute: Int = 0

    var reminderStartEnabled: Bool = false
    var reminderEndEnabled: Bool = false

    init(symbolsRaw: String = "EURUSD,GBPUSD,XAUUSD",
         minRR: Double = 2.0,
         ladder1: Double = 12,
         ladder2: Double = 25,
         ladder3: Double = 50,
         cycleStartHour: Int = 19,
         cycleStartMinute: Int = 0,
         cycleEndHour: Int = 22,
         cycleEndMinute: Int = 0) {
        self.symbolsRaw = symbolsRaw
        self.minRR = minRR
        self.ladder1 = ladder1
        self.ladder2 = ladder2
        self.ladder3 = ladder3
        self.cycleStartHour = cycleStartHour
        self.cycleStartMinute = cycleStartMinute
        self.cycleEndHour = cycleEndHour
        self.cycleEndMinute = cycleEndMinute
    }

    var symbols: [String] {
        get {
            symbolsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            symbolsRaw = newValue.joined(separator: ",")
        }
    }

    var ladderAmounts: [Double] {
        [ladder1, ladder2, ladder3]
    }

    func ladderAmount(at index: Int) -> Double {
        let safeIndex = min(max(index, 0), ladderAmounts.count - 1)
        return ladderAmounts[safeIndex]
    }
}

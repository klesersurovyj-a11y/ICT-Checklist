//
//  TradeShot.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class TradeShot {
    var fileName: String
    var createdAt: Date
    var trade: Trade?

    init(fileName: String, createdAt: Date = .now) {
        self.fileName = fileName
        self.createdAt = createdAt
        self.trade = nil
    }
}

extension Trade {
    var sortedShots: [TradeShot] {
        shots.sorted { $0.createdAt < $1.createdAt }
    }
}

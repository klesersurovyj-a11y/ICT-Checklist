//
//  TradeShot.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class TradeShot {
    /// Legacy name of the file written before screenshots moved into SwiftData.
    var fileName: String = ""
    /// Screenshot itself, stored externally and mirrored to iCloud as an asset.
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    var trade: Trade?

    init(fileName: String = "", imageData: Data? = nil, createdAt: Date = .now) {
        self.fileName = fileName
        self.imageData = imageData
        self.createdAt = createdAt
        self.trade = nil
    }
}

extension Trade {
    var sortedShots: [TradeShot] {
        shots.sorted { $0.createdAt < $1.createdAt }
    }
}

//
//  TradeShot.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Роль скриншота в разборе сделки.
enum ShotRole: String, CaseIterable, Identifiable {
    case general
    case beforeEntry
    case afterClose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "Скриншот"
        case .beforeEntry:
            return "До входа"
        case .afterClose:
            return "После закрытия"
        }
    }
}

@Model
final class TradeShot {
    /// Legacy name of the file written before screenshots moved into SwiftData.
    var fileName: String = ""
    /// Screenshot itself, stored externally and mirrored to iCloud as an asset.
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    /// Роль в разборе: обычный скриншот, «до входа» или «после закрытия».
    var roleRaw: String = ShotRole.general.rawValue
    var trade: Trade?

    init(
        fileName: String = "",
        imageData: Data? = nil,
        createdAt: Date = .now,
        role: ShotRole = .general
    ) {
        self.fileName = fileName
        self.imageData = imageData
        self.createdAt = createdAt
        self.roleRaw = role.rawValue
        self.trade = nil
    }

    var role: ShotRole {
        get { ShotRole(rawValue: roleRaw) ?? .general }
        set { roleRaw = newValue.rawValue }
    }
}

extension Trade {
    var sortedShots: [TradeShot] {
        shots.sorted { $0.createdAt < $1.createdAt }
    }

    func shot(with role: ShotRole) -> TradeShot? {
        sortedShots.first { $0.role == role }
    }
}

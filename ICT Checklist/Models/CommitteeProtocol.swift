//
//  CommitteeProtocol.swift
//  ICT Checklist
//
//  Протокол заседания комитета: решения по пунктам повестки,
//  дата и версия мандата.
//

import Foundation
import SwiftData

enum CommitteeAction: String, CaseIterable, Identifiable {
    case keep = "Оставить"
    case change = "Изменить"
    case rollback = "Откатить"

    var id: String { rawValue }
}

struct CommitteeDecision: Identifiable, Codable, Hashable {
    var id: String
    var text: String
    var actionRaw: String
    var note: String
    var createdAt: Date

    var action: CommitteeAction {
        CommitteeAction(rawValue: actionRaw) ?? .keep
    }
}

@Model
final class CommitteeProtocol {
    var createdAt: Date = Date()
    var weekStart: Date = Date()
    var mandateVersion: Int = 0
    var note: String = ""
    var signedAt: Date? = nil
    var decisionsRaw: String = ""

    init(weekStart: Date, mandateVersion: Int) {
        self.createdAt = .now
        self.weekStart = weekStart
        self.mandateVersion = mandateVersion
        self.note = ""
        self.signedAt = nil
        self.decisionsRaw = ""
    }

    var decisions: [CommitteeDecision] {
        get { CommitteeProtocol.decode(decisionsRaw) }
        set { decisionsRaw = CommitteeProtocol.encode(newValue) }
    }

    var isSigned: Bool { signedAt != nil }

    static func encode(_ decisions: [CommitteeDecision]) -> String {
        guard !decisions.isEmpty, let data = try? JSONEncoder().encode(decisions) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) -> [CommitteeDecision] {
        guard let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode([CommitteeDecision].self, from: data) else {
            return []
        }
        return value
    }
}

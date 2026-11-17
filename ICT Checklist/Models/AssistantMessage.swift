//
//  AssistantMessage.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Одна реплика диалога с ИИ-ассистентом.
@Model
final class AssistantMessage {
    var role: String = "user"
    var text: String = ""
    var createdAt: Date = Date()

    init(role: String, text: String) {
        self.role = role
        self.text = text
        self.createdAt = .now
    }

    var isUser: Bool { role == "user" }
}

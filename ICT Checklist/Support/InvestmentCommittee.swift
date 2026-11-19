//
//  InvestmentCommittee.swift
//  ICT Checklist
//
//  Инвестиционный комитет: меморандум сделки, красная команда и вердикт.
//

import SwiftUI

enum MemoVerdict: String {
    case none
    case approved
    case rejected

    var title: String {
        switch self {
        case .none: return "Черновик"
        case .approved: return "Утверждено"
        case .rejected: return "Отклонено"
        }
    }

    var icon: String {
        switch self {
        case .none: return "pencil"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .none: return Theme.textTertiary
        case .approved: return Theme.green
        case .rejected: return Theme.red
        }
    }
}

/// Возражение красной команды, на которое нужно ответить до входа.
struct RedTeamObjection: Identifiable {
    var id: String { title }
    let title: String
    let detail: String
}

enum InvestmentCommittee {
    static func objections(
        thesis: String,
        invalidation: String,
        checkedCount: Int,
        totalChecks: Int,
        rr: Double,
        minRR: Double
    ) -> [RedTeamObjection] {
        var list: [RedTeamObjection] = []

        if thesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            list.append(
                RedTeamObjection(
                    title: "Нет тезиса",
                    detail: "Напишите одной фразой, почему цена должна пойти к цели."
                )
            )
        }

        if invalidation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            list.append(
                RedTeamObjection(
                    title: "Не описана инвалидация",
                    detail: "Что именно отменит идею: закрытие за уровень, смена потока, новость."
                )
            )
        }

        if checkedCount < totalChecks {
            list.append(
                RedTeamObjection(
                    title: "Чек-лист не закрыт",
                    detail: "Отмечено \(checkedCount) из \(totalChecks). Незакрытые пункты — это непроверенные условия входа."
                )
            )
        }

        if minRR > 0, rr < minRR {
            list.append(
                RedTeamObjection(
                    title: "RR ниже минимума",
                    detail: "Плановый \(Fmt.rr(rr)) против минимума \(Fmt.rr(minRR)). Либо цена входа, либо цель должны измениться."
                )
            )
        }

        return list
    }

    static func canApprove(
        thesis: String,
        invalidation: String,
        objections: [RedTeamObjection],
        answers: String
    ) -> Bool {
        guard !thesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !invalidation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if objections.isEmpty { return true }
        return !answers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

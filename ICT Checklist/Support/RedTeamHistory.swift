//
//  RedTeamHistory.swift
//  ICT Checklist
//
//  Красная команда по вашей же истории: похожие сделки, их результат в R
//  и короткая причина, почему не сработало.
//

import Foundation
import SwiftData

/// Похожая сделка из журнала: чем закончилась и почему.
struct RedTeamEvidence: Identifiable, Codable, Hashable {
    var id: String
    var symbol: String
    var day: Date
    var r: Double
    var reason: String
}

/// Возражение красной команды, собранное по истории сделок.
struct RedTeamHistoryObjection: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var evidence: [RedTeamEvidence] = []
}

enum RedTeamHistory {
    /// Черновик сделки, по которому комитет ищет похожие случаи.
    struct Draft {
        var symbol: String
        var direction: Direction
        var setupName: String
        var session: MarketSession
    }

    static func draft(for trade: Trade) -> Draft {
        Draft(
            symbol: trade.symbol,
            direction: trade.direction,
            setupName: setupTitle(of: trade),
            session: trade.marketSession
        )
    }

    static func draft(
        symbol: String,
        direction: Direction,
        setupName: String,
        date: Date = .now
    ) -> Draft {
        let hour = MarketBehavior.utcCalendar.component(.hour, from: date)
        return Draft(
            symbol: symbol,
            direction: direction,
            setupName: setupName,
            session: MarketSession(hourUTC: hour)
        )
    }

    static func setupTitle(of trade: Trade) -> String {
        let named = trade.setupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !named.isEmpty {
            return named
        }
        return trade.setup?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func objections(
        for draft: Draft,
        trades: [Trade],
        excluding excluded: Trade? = nil
    ) -> [RedTeamHistoryObjection] {
        let closed: [Trade] = trades.filter { trade in
            guard trade.result != .open else { return false }
            guard let excluded else { return true }
            return trade.persistentModelID != excluded.persistentModelID
        }
        guard !closed.isEmpty else { return [] }

        var result: [RedTeamHistoryObjection] = []

        // 1. Тот же сетап плейбука.
        let setupName = draft.setupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !setupName.isEmpty {
            let same = closed.filter {
                setupTitle(of: $0).caseInsensitiveCompare(setupName) == .orderedSame
            }
            let losses = same.filter { $0.actualR < -0.05 }
            if losses.count >= 2 {
                let sum = losses.reduce(0) { $0 + $1.actualR }
                result.append(
                    RedTeamHistoryObjection(
                        id: "history.setup",
                        title: "Сетап «\(setupName)» уже отдавал",
                        detail: "\(Fmt.deals(losses.count)) по этому сетапу закрылись в минус, сумма \(Fmt.r(sum)) из \(Fmt.deals(same.count)).",
                        evidence: evidence(from: losses)
                    )
                )
            }
        }

        // 2. Тот же инструмент.
        let symbol = draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if !symbol.isEmpty {
            let same = closed.filter { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
            let losses = same.filter { $0.actualR < -0.05 }
            if losses.count >= 3 {
                let sum = losses.reduce(0) { $0 + $1.actualR }
                result.append(
                    RedTeamHistoryObjection(
                        id: "history.symbol",
                        title: "По \(symbol.uppercased()) минус повторяется",
                        detail: "\(Fmt.deals(losses.count)) в минус, сумма \(Fmt.r(sum)) из \(Fmt.deals(same.count)) по инструменту.",
                        evidence: evidence(from: losses)
                    )
                )
            }
        }

        // 3. Та же сессия: своя же статистика хуже.
        let sessionTrades = closed.filter { $0.marketSession == draft.session }
        if sessionTrades.count >= 3 {
            let sessionAvg = sessionTrades.reduce(0) { $0 + $1.actualR } / Double(sessionTrades.count)
            let overallAvg = closed.reduce(0) { $0 + $1.actualR } / Double(closed.count)
            if sessionAvg < overallAvg - 0.1 {
                let losses = sessionTrades.filter { $0.actualR < -0.05 }
                result.append(
                    RedTeamHistoryObjection(
                        id: "history.session",
                        title: "В сессии «\(draft.session.rawValue)» статистика хуже",
                        detail: "\(Fmt.deals(sessionTrades.count)) в этой сессии, средняя \(Fmt.r(sessionAvg)) против \(Fmt.r(overallAvg)) по журналу.",
                        evidence: evidence(from: losses)
                    )
                )
            }
        }

        // 4. Уже открытая позиция в ту же сторону.
        let openSame = trades.filter { trade in
            guard trade.result == .open, trade.direction == draft.direction else { return false }
            guard let excluded else { return true }
            return trade.persistentModelID != excluded.persistentModelID
        }
        if !openSame.isEmpty {
            let list = openSame.prefix(3)
                .map { "\($0.symbol.uppercased()) \($0.direction.rawValue)" }
                .joined(separator: ", ")
            let extra = openSame.count > 3 ? " и ещё \(openSame.count - 3)" : ""
            result.append(
                RedTeamHistoryObjection(
                    id: "history.exposure",
                    title: "Открыта позиция в том же направлении",
                    detail: "\(list)\(extra). Вторая ставка в ту же сторону удваивает риск, если инструменты идут вместе."
                )
            )
        }

        return result
    }

    /// На каждое возражение по истории должен быть ответ.
    static func isAnswered(_ objections: [RedTeamHistoryObjection], replies: [String: String]) -> Bool {
        objections.allSatisfy { objection in
            !(replies[objection.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Короткая причина, почему сделка не сработала.
    static func reason(for trade: Trade) -> String {
        if let text = trimmed(trade.review?.resultReason) {
            return shortened(text)
        }
        if let text = trimmed(trade.lossReview?.note) {
            return shortened(text)
        }
        if let text = trimmed(trade.note) {
            return shortened(text)
        }
        if let title = trade.errorNotes.compactMap({ trimmed($0.title) }).first {
            return shortened(title)
        }
        return "причина не записана"
    }

    private static func evidence(from trades: [Trade], limit: Int = 3) -> [RedTeamEvidence] {
        trades
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
            .prefix(limit)
            .map { trade in
                RedTeamEvidence(
                    id: String(trade.persistentModelID.hashValue),
                    symbol: trade.symbol.uppercased(),
                    day: trade.tradingDay,
                    r: trade.actualR,
                    reason: reason(for: trade)
                )
            }
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let text else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func shortened(_ text: String, limit: Int = 80) -> String {
        let single = text.replacingOccurrences(of: "\n", with: " ")
        return single.count <= limit ? single : String(single.prefix(limit)) + "…"
    }

    // MARK: - Хранение в сделке

    static func encode(replies: [String: String]) -> String {
        guard !replies.isEmpty, let data = try? JSONEncoder().encode(replies) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decodeReplies(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return value
    }

    static func encode(history: [RedTeamHistoryObjection]) -> String {
        guard !history.isEmpty, let data = try? JSONEncoder().encode(history) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decodeHistory(_ raw: String) -> [RedTeamHistoryObjection] {
        guard let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode([RedTeamHistoryObjection].self, from: data) else {
            return []
        }
        return value
    }

    /// Ответы без пустых строк — так они и сохраняются.
    static func cleaned(_ replies: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in replies {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                result[key] = text
            }
        }
        return result
    }
}

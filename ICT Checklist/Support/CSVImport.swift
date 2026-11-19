//
//  CSVImport.swift
//  ICT Checklist
//
//  Импорт сделок из CSV: разбор колонок, предпросмотр и запись в журнал.
//

import Foundation
import SwiftData

struct CSVImportRow: Identifiable {
    let id = UUID()
    let date: Date
    let symbol: String
    let direction: Direction
    let entry: Double
    let stop: Double
    let take: Double
    let result: TradeResult
    let actualR: Double
    let riskUSD: Double

    var plannedRR: Double {
        let risk = abs(entry - stop)
        let reward = abs(take - entry)
        guard risk > 0, reward > 0 else {
            return max(abs(actualR), 1)
        }
        return reward / risk
    }
}

enum CSVImportError: LocalizedError {
    case unreadable
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Не удалось прочитать файл. Нужен CSV с текстом в UTF-8."
        case .empty:
            return "В файле не нашлось подходящих строк со сделками."
        }
    }
}

enum CSVImport {
    struct Columns {
        var date: Int?
        var symbol: Int?
        var direction: Int?
        var entry: Int?
        var stop: Int?
        var take: Int?
        var result: Int?
        var r: Int?
        var risk: Int?
    }

    // MARK: - Parse

    static func parse(text: String) throws -> [CSVImportRow] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let header = lines.first else { throw CSVImportError.empty }

        let separator = delimiter(in: header)
        let headerFields = splitLine(header, separator: separator).map {
            $0.lowercased().trimmingCharacters(in: .whitespaces)
        }

        var columns = detect(headerFields)

        if columns.date == nil || columns.symbol == nil {
            columns = Columns(
                date: 0,
                symbol: 1,
                direction: 2,
                entry: 3,
                stop: 4,
                take: 5,
                result: 6,
                r: 7,
                risk: 8
            )
        }

        var rows: [CSVImportRow] = []

        for line in lines.dropFirst() {
            let fields = splitLine(line, separator: separator)
            guard let row = row(from: fields, columns: columns) else { continue }
            rows.append(row)
        }

        guard !rows.isEmpty else { throw CSVImportError.empty }
        return rows
    }

    static func lineCount(_ text: String) -> Int {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    static func readText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw CSVImportError.unreadable
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .windowsCP1251) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }

        throw CSVImportError.unreadable
    }

    // MARK: - Import

    static func importRows(
        _ rows: [CSVImportRow],
        account: TradingAccount?,
        context: ModelContext
    ) -> (added: Int, skipped: Int) {
        let existing = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let calendar = Calendar.current

        var keys = Set(existing.map { key(for: $0.tradingDay, symbol: $0.symbol, calendar: calendar) })

        var added = 0
        var skipped = 0

        for row in rows {
            let day = calendar.startOfDay(for: row.date)
            let rowKey = key(for: day, symbol: row.symbol, calendar: calendar)

            guard !keys.contains(rowKey) else {
                skipped += 1
                continue
            }

            let trade = Trade(
                entryDate: row.date,
                tradingDay: day,
                symbol: row.symbol,
                direction: row.direction,
                ladderStepIndex: 0,
                riskUSD: row.riskUSD,
                entry: row.entry,
                stop: row.stop,
                takeProfit: row.take,
                plannedRR: row.plannedRR,
                note: "Импорт из CSV",
                closedAt: row.result == .open ? nil : row.date.addingTimeInterval(3600)
            )
            trade.result = row.result
            trade.actualR = row.actualR
            trade.isBE = row.result == .be
            trade.account = account
            trade.isDemo = false

            context.insert(trade)
            keys.insert(rowKey)
            added += 1
        }

        try? context.save()
        return (added, skipped)
    }

    private static func key(for day: Date, symbol: String, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let stamp = String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
        return "\(stamp)|\(symbol.uppercased())"
    }

    // MARK: - Columns

    private static func detect(_ header: [String]) -> Columns {
        func index(_ keys: [String]) -> Int? {
            header.firstIndex { column in
                keys.contains { column.contains($0) }
            }
        }

        return Columns(
            date: index(["date", "дата", "time", "время", "open time", "открыта"]),
            symbol: index(["symbol", "символ", "pair", "инструмент", "instrument", "ticker"]),
            direction: index(["direction", "направление", "side", "тип сделки", "buy/sell"]),
            entry: index(["entry", "вход", "open price", "цена входа"]),
            stop: index(["stop loss", "stop", "стоп", "sl"]),
            take: index(["take profit", "take", "тейк", "tp", "target"]),
            result: index(["result", "результат", "outcome", "status"]),
            r: index(["r multiple", "r_multiple", "profit r", "в r", "r"]),
            risk: index(["risk", "риск"])
        )
    }

    // MARK: - Row

    private static func row(from fields: [String], columns: Columns) -> CSVImportRow? {
        func value(_ index: Int?) -> String {
            guard let index, index < fields.count else { return "" }
            return fields[index].trimmingCharacters(in: .whitespaces)
        }

        guard let date = parseDate(value(columns.date)) else { return nil }

        let symbol = value(columns.symbol).uppercased()
        guard symbol.count >= 3 else { return nil }

        guard let entry = parseNumber(value(columns.entry)), entry > 0 else { return nil }
        guard let stop = parseNumber(value(columns.stop)), stop > 0 else { return nil }

        let take = parseNumber(value(columns.take)) ?? 0
        let direction = parseDirection(value(columns.direction), entry: entry, stop: stop)
        let result = parseResult(value(columns.result))
        let risk = parseNumber(value(columns.risk)) ?? 0

        let parsedR = parseNumber(value(columns.r))
        let actualR: Double
        if let parsedR {
            actualR = parsedR
        } else {
            switch result {
            case .tp:
                actualR = take > 0 ? abs(take - entry) / abs(entry - stop) : 1
            case .sl:
                actualR = -1
            case .be, .open:
                actualR = 0
            }
        }

        return CSVImportRow(
            date: date,
            symbol: symbol,
            direction: direction,
            entry: entry,
            stop: stop,
            take: take,
            result: result,
            actualR: actualR,
            riskUSD: risk > 0 ? risk : 0
        )
    }

    // MARK: - Values

    private static func delimiter(in header: String) -> Character {
        let candidates: [Character] = [";", ",", "\t"]
        let counts = candidates.map { candidate in
            header.reduce(0) { $0 + ($1 == candidate ? 1 : 0) }
        }
        if let best = counts.max(), best > 0,
           let index = counts.firstIndex(of: best) {
            return candidates[index]
        }
        return ";"
    }

    private static func splitLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for character in line {
            if character == "\"" {
                inQuotes.toggle()
                continue
            }
            if character == separator, !inQuotes {
                fields.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        fields.append(current)

        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseNumber(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        var value = text
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "R", with: "")
            .replacingOccurrences(of: "р", with: "")
        if value.hasPrefix("+") {
            value.removeFirst()
        }
        return Double(value)
    }

    private static func parseDirection(_ text: String, entry: Double, stop: Double) -> Direction {
        let value = text.lowercased()
        if value.contains("short") || value.contains("sell") || value.contains("шорт") || value.contains("продаж") {
            return .short
        }
        if value.contains("long") || value.contains("buy") || value.contains("лонг") || value.contains("покуп") {
            return .long
        }
        return stop <= entry ? .long : .short
    }

    private static func parseResult(_ text: String) -> TradeResult {
        let value = text.lowercased().trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return .open }

        if value.contains("tp") || value.contains("take") || value.contains("win")
            || value.contains("профит") || value.contains("прибыл") {
            return .tp
        }
        if value.contains("sl") || value.contains("stop") || value.contains("loss")
            || value.contains("убыт") || value.contains("стоп") {
            return .sl
        }
        if value.contains("be") || value.contains("breakeven") || value.contains("безуб") {
            return .be
        }
        if value.contains("open") || value.contains("открыт") {
            return .open
        }
        return .open
    }

    private static let dateFormats: [String] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy.MM.dd HH:mm:ss",
        "yyyy.MM.dd HH:mm",
        "yyyy.MM.dd",
        "dd.MM.yyyy HH:mm:ss",
        "dd.MM.yyyy HH:mm",
        "dd.MM.yyyy",
        "dd.MM.yy HH:mm",
        "dd/MM/yyyy HH:mm",
        "MM/dd/yyyy HH:mm",
        "dd/MM/yyyy",
        "yyyy-MM-dd"
    ]

    private static func parseDate(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}

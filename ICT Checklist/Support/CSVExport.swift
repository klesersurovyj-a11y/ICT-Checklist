//
//  CSVExport.swift
//  ICT Checklist
//

import Foundation

enum CSVExport {
    enum ExportError: Error {
        case encoding
    }

    static func writeFiles(trades: [Trade], cycles: [TradingCycle]) throws -> [URL] {
        let stamp = fileStampFormatter.string(from: .now)
        let directory = FileManager.default.temporaryDirectory
        let tradesURL = directory.appendingPathComponent("ICT Checklist — сделки \(stamp).csv")
        let cyclesURL = directory.appendingPathComponent("ICT Checklist — циклы \(stamp).csv")

        try write(tradesCSV(trades), to: tradesURL)
        try write(cyclesCSV(cycles), to: cyclesURL)
        return [tradesURL, cyclesURL]
    }

    // MARK: - Trades

    static func tradesCSV(_ trades: [Trade]) -> String {
        var rows: [String] = []
        rows.append(
            line([
                "Торговый день",
                "Дата и время входа",
                "Символ",
                "Направление",
                "Ступень",
                "Риск, $",
                "Entry",
                "SL изначальный",
                "SL после BE",
                "TP",
                "Плановый RR",
                "Результат",
                "Фактический R",
                "B дал объём",
                "Метки",
                "Заметка"
            ])
        )

        let sorted = trades.sorted { first, second in
            if first.tradingDay != second.tradingDay { return first.tradingDay < second.tradingDay }
            return first.entryDate < second.entryDate
        }

        for trade in sorted {
            rows.append(
                line([
                    dayFormatter.string(from: trade.tradingDay),
                    dateTimeFormatter.string(from: trade.entryDate),
                    trade.symbol,
                    trade.direction.rawValue,
                    "\(trade.ladderStepIndex + 1)",
                    decimal(trade.riskUSD, digits: 2),
                    decimal(trade.entry, digits: 5),
                    decimal(trade.originalStop, digits: 5),
                    trade.isBE ? decimal(trade.currentStop, digits: 5) : "",
                    decimal(trade.takeProfit, digits: 5),
                    decimal(trade.plannedRR, digits: 2),
                    resultText(trade),
                    trade.result == .open ? "" : decimal(trade.actualR, digits: 2),
                    volumeText(trade),
                    trade.tags.joined(separator: ", "),
                    trade.note
                ])
            )
        }

        return rows.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Cycles

    static func cyclesCSV(_ cycles: [TradingCycle]) -> String {
        var rows: [String] = []
        rows.append(
            line([
                "Торговый день",
                "Новости",
                "Направление",
                "DR верх",
                "DR низ",
                "Зона",
                "Point A",
                "Point B",
                "Итог дня",
                "STOP DAY"
            ])
        )

        let sorted = cycles.sorted { $0.day < $1.day }

        for cycle in sorted {
            rows.append(
                line([
                    dayFormatter.string(from: cycle.day),
                    newsText(cycle),
                    cycle.direction.rawValue,
                    decimal(cycle.drHigh, digits: 5),
                    decimal(cycle.drLow, digits: 5),
                    cycle.zone?.rawValue ?? "",
                    decimal(cycle.pointAPrice, digits: 5),
                    decimal(cycle.pointBPrice, digits: 5),
                    dayResultText(cycle),
                    cycle.stopDay ? "да" : "нет"
                ])
            )
        }

        return rows.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Helpers

    private static func write(_ string: String, to url: URL) throws {
        let bom = "\u{FEFF}"
        guard let data = (bom + string).data(using: .utf8) else {
            throw ExportError.encoding
        }
        try data.write(to: url, options: .atomic)
    }

    private static func line(_ values: [String]) -> String {
        values.map(field).joined(separator: ";")
    }

    private static func field(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func resultText(_ trade: Trade) -> String {
        switch trade.result {
        case .open: return "Открыта"
        case .tp: return "TP"
        case .sl: return "SL"
        case .be: return "BE"
        }
    }

    private static func dayResultText(_ cycle: TradingCycle) -> String {
        switch cycle.result {
        case .draft: return "Черновик"
        case .entry: return "Сделка"
        case .stopped: return "STOP DAY"
        }
    }

    private static func volumeText(_ trade: Trade) -> String {
        guard trade.result == .tp else { return "" }
        guard let cycle = trade.cycle, cycle.tpVolumeAnswered else { return "" }
        return cycle.tpVolumeGiven ? "да" : "нет"
    }

    private static func newsText(_ cycle: TradingCycle) -> String {
        let flags = [
            "EUR: \(cycle.newsEUR ? "важно" : "нет")",
            "GBP: \(cycle.newsGBP ? "важно" : "нет")",
            "USD: \(cycle.newsUSD ? "важно" : "нет")"
        ].joined(separator: ", ")
        let note = cycle.newsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? flags : "\(flags) — \(note)"
    }

    private static func decimal(_ value: Double?, digits: Int) -> String {
        guard let value else { return "" }
        let formatter: NumberFormatter
        switch digits {
        case 1: formatter = oneDigitFormatter
        case 2: formatter = twoDigitsFormatter
        default: formatter = priceFormatter
        }
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter
    }()

    private static func makeNumberFormatter(digits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        return formatter
    }

    private static let priceFormatter = makeNumberFormatter(digits: 5)
    private static let twoDigitsFormatter = makeNumberFormatter(digits: 2)
    private static let oneDigitFormatter = makeNumberFormatter(digits: 1)
}

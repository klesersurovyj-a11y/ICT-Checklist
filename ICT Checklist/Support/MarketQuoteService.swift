//
//  MarketQuoteService.swift
//  ICT Checklist
//
//  Расширенные котировки для терминала: цена, изменение за день, дневной диапазон.
//

import Foundation

struct TerminalQuote: Codable {
    var symbol: String
    var price: Double
    var change: Double
    var percentChange: Double
    var dayHigh: Double
    var dayLow: Double
    var updatedAt: Date
}

enum MarketQuoteService {
    static func fetch(symbol: String) async throws -> TerminalQuote {
        let key = (ApiKeyManager.shared.get(key: "TWELVE_DATA_API_KEY") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        var components = URLComponents(string: "https://api.twelvedata.com/quote")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: PriceBook.apiSymbol(for: symbol)),
            URLQueryItem(name: "apikey", value: key)
        ]

        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        if let status = json["status"] as? String, status == "error" {
            throw URLError(.cannotParseResponse)
        }

        func number(_ key: String) -> Double? {
            if let value = json[key] as? NSNumber { return value.doubleValue }
            if let text = json[key] as? String {
                return Double(text.replacingOccurrences(of: ",", with: "."))
            }
            return nil
        }

        guard let price = number("close") ?? number("price") else {
            throw URLError(.cannotParseResponse)
        }

        let change = number("change") ?? 0
        let percent = number("percent_change")
            ?? (price - change != 0 ? change / (price - change) * 100 : 0)

        return TerminalQuote(
            symbol: symbol.uppercased(),
            price: price,
            change: change,
            percentChange: percent,
            dayHigh: number("high") ?? price,
            dayLow: number("low") ?? price,
            updatedAt: .now
        )
    }

    // MARK: - Cache

    private static var cacheURL: URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("terminal_quotes.json")
    }

    static func saveCache(_ quotes: [String: TerminalQuote]) {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func loadCache() -> [String: TerminalQuote] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: TerminalQuote].self, from: data)) ?? [:]
    }

    // MARK: - Формат

    static func priceText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true

        if abs(value) >= 1000 {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        } else if abs(value) >= 100 {
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 1
        } else if abs(value) >= 10 {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        } else {
            formatter.maximumFractionDigits = 4
            formatter.minimumFractionDigits = 4
        }

        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func rangeText(_ quote: TerminalQuote) -> String {
        "\(priceText(quote.dayLow)) – \(priceText(quote.dayHigh))"
    }

    static func changeText(_ quote: TerminalQuote) -> String {
        let sign = quote.percentChange > 0.005 ? "+" : (quote.percentChange < -0.005 ? "\u{2212}" : "")
        return sign + String(format: "%.2f%%", abs(quote.percentChange))
    }
}

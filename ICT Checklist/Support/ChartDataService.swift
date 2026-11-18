//
//  ChartDataService.swift
//  ICT Checklist
//
//  Свечи с Twelve Data для графика TradingView (Lightweight Charts).
//

import Foundation

struct ChartBar: Codable {
    let time: Int
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

struct ChartPriceLine: Codable {
    let price: Double
    let title: String
    let color: String
    /// 0 — сплошная, 1 — точки, 2 — штрих.
    let style: Int
}

enum ChartDataError: LocalizedError {
    case missingKey
    case network(String)
    case server(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Нужен ключ TWELVE_DATA_API_KEY, чтобы загрузить свечи."
        case .network(let message):
            return message
        case .server(let message):
            return message
        case .empty:
            return "По этому инструменту нет свечей за выбранный период."
        }
    }
}

/// Кэш свечей: свежие — в памяти, старые — на диске, чтобы график
/// открывался без сети и не тратил лимит Twelve Data.
actor ChartDataCache {
    static let shared = ChartDataCache()

    private struct Entry: Codable {
        let bars: [ChartBar]
        let savedAt: Date
    }

    private var memory: [String: Entry] = [:]

    func fresh(_ key: String, maxAge: TimeInterval) -> [ChartBar]? {
        if let entry = memory[key], Date().timeIntervalSince(entry.savedAt) < maxAge {
            return entry.bars
        }
        guard let entry = diskEntry(key),
              Date().timeIntervalSince(entry.savedAt) < maxAge else {
            return nil
        }
        memory[key] = entry
        return entry.bars
    }

    func stored(_ key: String) -> [ChartBar]? {
        if let entry = memory[key] {
            return entry.bars
        }
        guard let entry = diskEntry(key) else { return nil }
        memory[key] = entry
        return entry.bars
    }

    func save(_ key: String, bars: [ChartBar]) {
        let entry = Entry(bars: bars, savedAt: .now)
        memory[key] = entry
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(
            at: Self.directory,
            withIntermediateDirectories: true
        )
        try? data.write(to: Self.url(for: key), options: .atomic)
    }

    private func diskEntry(_ key: String) -> Entry? {
        guard let data = try? Data(contentsOf: Self.url(for: key)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ChartCache", isDirectory: true)
    }

    private static func url(for key: String) -> URL {
        let name = Data(key.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent(name + ".json")
    }
}

enum ChartDataService {
    static func candles(
        symbol: String,
        interval: TVInterval,
        count: Int = 300
    ) async throws -> [ChartBar] {
        let cacheKey = "\(symbol.uppercased())|\(interval.rawValue)|\(count)"

        if let cached = await ChartDataCache.shared.fresh(cacheKey, maxAge: 300) {
            return cached
        }

        let key = (ApiKeyManager.shared.get(key: "TWELVE_DATA_API_KEY") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ChartDataError.missingKey }

        do {
            var components = URLComponents(string: "https://api.twelvedata.com/time_series")
            components?.queryItems = [
                URLQueryItem(name: "symbol", value: apiSymbol(for: symbol)),
                URLQueryItem(name: "interval", value: interval.twelveData),
                URLQueryItem(name: "outputsize", value: "\(count)"),
                URLQueryItem(name: "timezone", value: "UTC"),
                URLQueryItem(name: "apikey", value: key)
            ]

            guard let url = components?.url else {
                throw ChartDataError.network("Не удалось собрать запрос свечей.")
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw ChartDataError.network("Нет связи с Twelve Data: \(error.localizedDescription)")
            }

            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw ChartDataError.server("Twelve Data ответил ошибкой \(http.statusCode).")
            }

            let payload: Response
            do {
                payload = try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw ChartDataError.network("Не удалось разобрать свечи Twelve Data.")
            }

            if let message = payload.message, !message.isEmpty {
                let capitalized = message.prefix(1).uppercased() + message.dropFirst()
                throw ChartDataError.server(String(capitalized))
            }
            guard let values = payload.values, !values.isEmpty else {
                throw ChartDataError.empty
            }

            let bars = values.compactMap { value -> ChartBar? in
                guard let date = parseDate(value.datetime),
                      let open = Double(value.open.replacingOccurrences(of: ",", with: ".")),
                      let high = Double(value.high.replacingOccurrences(of: ",", with: ".")),
                      let low = Double(value.low.replacingOccurrences(of: ",", with: ".")),
                      let close = Double(value.close.replacingOccurrences(of: ",", with: ".")) else {
                    return nil
                }
                return ChartBar(
                    time: Int(date.timeIntervalSince1970),
                    open: open,
                    high: high,
                    low: low,
                    close: close
                )
            }
            .sorted { $0.time < $1.time }

            guard !bars.isEmpty else { throw ChartDataError.empty }
            await ChartDataCache.shared.save(cacheKey, bars: bars)
            return bars
        } catch {
            if let cached = await ChartDataCache.shared.stored(cacheKey) {
                return cached
            }
            throw error
        }
    }

    // MARK: - Разбор

    /// EURUSD → EUR/USD, XAUUSD → XAU/USD, BTCUSD → BTC/USD.
    private static func apiSymbol(for symbol: String) -> String {
        let value = symbol
            .uppercased()
            .replacingOccurrences(of: "/", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard value.count == 6 else {
            return symbol.uppercased()
        }

        let base = String(value.prefix(3))
        let quote = String(value.suffix(3))
        let units: Set<String> = [
            "USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD",
            "XAU", "XAG", "BTC", "ETH"
        ]

        guard units.contains(base), units.contains(quote) else {
            return symbol.uppercased()
        }
        return "\(base)/\(quote)"
    }

    private struct Response: Decodable {
        struct Value: Decodable {
            let datetime: String
            let open: String
            let high: String
            let low: String
            let close: String
        }

        let values: [Value]?
        let status: String?
        let message: String?
    }

    private static let parsers: [DateFormatter] = {
        ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static func parseDate(_ value: String) -> Date? {
        for parser in parsers {
            if let date = parser.date(from: value) {
                return date
            }
        }
        return nil
    }
}

extension TVInterval {
    var twelveData: String {
        switch self {
        case .m15: return "15min"
        case .h1: return "1h"
        case .h4: return "4h"
        case .d1: return "1day"
        case .w1: return "1week"
        }
    }
}

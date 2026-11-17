//
//  PriceBook.swift
//  ICT Checklist
//

import Foundation
import Combine
import SwiftData

/// Котировка с рынка для одного символа.
struct Quote: Equatable {
    var symbol: String
    var price: Double
    var updatedAt: Date
}

/// Живые цены с Twelve Data. Ключ TWELVE_DATA_API_KEY хранится в связке ключей.
@MainActor
final class PriceBook: ObservableObject {
    static let shared = PriceBook()

    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasKey = false

    private var lastFetch: [String: Date] = [:]
    private var inFlight = false

    private init() {
        hasKey = ApiKeyManager.shared.has(key: "TWELVE_DATA_API_KEY")
    }

    func quote(for symbol: String) -> Quote? {
        quotes[symbol.uppercased()]
    }

    func refresh(symbols: Set<String>, force: Bool = false) async {
        let key = (ApiKeyManager.shared.get(key: "TWELVE_DATA_API_KEY") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        hasKey = !key.isEmpty

        guard !key.isEmpty else {
            lastError = "Нет ключа TWELVE_DATA_API_KEY"
            return
        }
        guard !symbols.isEmpty, !inFlight else { return }

        inFlight = true
        isRefreshing = true
        defer {
            inFlight = false
            isRefreshing = false
        }

        let now = Date()
        var fetched = 0
        var failure: String?

        for symbol in symbols.sorted() {
            let name = symbol.uppercased()
            if !force, let last = lastFetch[name], now.timeIntervalSince(last) < 40 {
                continue
            }
            // Бесплатный тариф Twelve Data: 8 запросов в минуту.
            if fetched >= 4 { break }

            do {
                if let quote = try await fetch(name: name, apiKey: key) {
                    quotes[name] = quote
                    lastFetch[name] = now
                }
            } catch {
                failure = (error as? PriceError)?.message ?? error.localizedDescription
            }

            fetched += 1
        }

        lastError = failure
    }

    private func fetch(name: String, apiKey: String) async throws -> Quote? {
        var components = URLComponents(string: "https://api.twelvedata.com/price")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: Self.apiSymbol(for: name)),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PriceError.message("Сервис цен недоступен")
        }

        if let payload = try? JSONDecoder().decode(PriceResponse.self, from: data),
           let price = Double(payload.price.replacingOccurrences(of: ",", with: ".")) {
            return Quote(symbol: name, price: price, updatedAt: .now)
        }

        if let payload = try? JSONDecoder().decode(ErrorResponse.self, from: data),
           let message = payload.message {
            throw PriceError.message(message.capitalizedFirst)
        }

        return nil
    }

    /// EURUSD → EUR/USD, XAUUSD → XAU/USD, BTCUSD → BTC/USD.
    static func apiSymbol(for symbol: String) -> String {
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

    private struct PriceResponse: Decodable {
        let price: String
    }

    private struct ErrorResponse: Decodable {
        let message: String?
    }
}

enum PriceError: Error {
    case message(String)

    var message: String {
        switch self {
        case .message(let text): return text
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + String(dropFirst())
    }
}

/// Расчёт расстояний до уровней сделки и автозакрытие по рынку.
@MainActor
enum PriceMonitor {
    struct Distances {
        var toStopR: Double
        var toTargetR: Double
        var toBreakEvenR: Double
    }

    static func openSymbols(_ trades: [Trade]) -> Set<String> {
        Set(
            trades
                .filter { $0.result == .open }
                .map { $0.symbol.uppercased() }
        )
    }

    static func distances(_ trade: Trade, price: Double) -> Distances? {
        let risk = abs(trade.entry - trade.originalStop)
        guard risk > 0, trade.entry != 0 else { return nil }

        let sign: Double = trade.direction == .long ? 1 : -1
        return Distances(
            toStopR: (price - trade.currentStop) * sign / risk,
            toTargetR: (trade.takeProfit - price) * sign / risk,
            toBreakEvenR: (price - trade.entry) * sign / risk
        )
    }

    /// Закрывает открытые сделки, если цена дошла до TP или SL.
    @discardableResult
    static func evaluate(
        trades: [Trade],
        context: ModelContext,
        autoClose: Bool
    ) -> [Trade] {
        guard autoClose else { return [] }

        var closed: [Trade] = []

        for trade in trades where trade.result == .open {
            guard let quote = PriceBook.shared.quote(for: trade.symbol) else { continue }
            let price = quote.price

            let hitTarget = trade.direction == .long
                ? price >= trade.takeProfit
                : price <= trade.takeProfit
            let hitStop = trade.direction == .long
                ? price <= trade.currentStop
                : price >= trade.currentStop

            if hitTarget {
                close(trade, as: .tp, price: price, context: context)
                closed.append(trade)
            } else if hitStop {
                close(trade, as: .sl, price: price, context: context)
                closed.append(trade)
            }
        }

        return closed
    }

    private static func close(
        _ trade: Trade,
        as result: TradeResult,
        price: Double,
        context: ModelContext
    ) {
        switch result {
        case .tp:
            trade.actualR = trade.plannedRR
        case .sl:
            trade.actualR = trade.isBE ? 0 : -1
        case .be:
            trade.actualR = 0
        case .open:
            return
        }

        trade.result = result
        trade.closedAt = .now

        if result == .sl,
           let cycle = trade.cycle,
           Calendar.current.isDateInToday(trade.tradingDay) {
            cycle.stopDay = true
            cycle.updatedAt = .now
        }

        try? context.save()
        LadderEngine.sync(context: context)
        GoalReminder.check(context: context)
        DailyLimitReminder.check(context: context)

        ReminderService.notifyClosed(
            symbol: trade.symbol,
            result: result,
            r: trade.actualR,
            price: price
        )
    }
}

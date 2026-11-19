//
//  WorldEconomyService.swift
//  ICT Checklist
//
//  Экономические показатели ключевых регионов для мировой карты.
//

import Foundation
import CoreLocation

enum EconomyRegion: String, CaseIterable, Identifiable {
    case usa = "США"
    case uk = "Британия"
    case europe = "Европа"

    var id: String { rawValue }

    var countryCode: String {
        switch self {
        case .usa: return "USA"
        case .uk: return "GBR"
        case .europe: return "EMU"
        }
    }

    var currency: String {
        switch self {
        case .usa: return "USD"
        case .uk: return "GBP"
        case .europe: return "EUR"
        }
    }

    var centralBank: String {
        switch self {
        case .usa: return "ФРС"
        case .uk: return "Банк Англии"
        case .europe: return "ЕЦБ"
        }
    }

    var nativeAssets: [String] {
        switch self {
        case .usa: return ["USD", "US500", "US30", "NAS100"]
        case .uk: return ["GBP", "UK100"]
        case .europe: return ["EUR", "GER40", "EU50"]
        }
    }

    var session: String {
        switch self {
        case .usa: return "Нью-Йорк · 16:30–23:00 МСК"
        case .uk: return "Лондон · 11:00–19:30 МСК"
        case .europe: return "Франкфурт · 11:00–19:30 МСК"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .usa: return CLLocationCoordinate2D(latitude: 38.9, longitude: -77.0)
        case .uk: return CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)
        case .europe: return CLLocationCoordinate2D(latitude: 50.1, longitude: 8.7)
        }
    }
}

struct EconomySnapshot: Codable {
    var regionCode: String
    var growth: Double?
    var inflation: Double?
    var unemployment: Double?
    var gdpUSD: Double?
    var year: String?
    var updatedAt: Date

    func value(_ key: KeyPath<EconomySnapshot, Double?>) -> Double? {
        self[keyPath: key]
    }
}

enum WorldEconomyService {
    private static let base = "https://api.worldbank.org/v2/country"

    private struct Indicator {
        let code: String
    }

    private static let growthIndicator = Indicator(code: "NY.GDP.MKTP.KD.ZG")
    private static let inflationIndicator = Indicator(code: "FP.CPI.TOTL.ZG")
    private static let unemploymentIndicator = Indicator(code: "SL.UEM.TOTL.ZS")
    private static let gdpIndicator = Indicator(code: "NY.GDP.MKTP.CD")

    static func fetch() async throws -> [String: EconomySnapshot] {
        let growth = try await latest(indicator: growthIndicator)
        let inflation = try await latest(indicator: inflationIndicator)
        let unemployment = try await latest(indicator: unemploymentIndicator)
        let gdp = try await latest(indicator: gdpIndicator)

        var result: [String: EconomySnapshot] = [:]
        for region in EconomyRegion.allCases {
            let code = region.countryCode
            let growthEntry = growth[code]
            result[code] = EconomySnapshot(
                regionCode: code,
                growth: growthEntry?.value,
                inflation: inflation[code]?.value,
                unemployment: unemployment[code]?.value,
                gdpUSD: gdp[code]?.value,
                year: growthEntry?.date ?? gdp[code]?.date,
                updatedAt: .now
            )
        }
        saveCache(result)
        return result
    }

    private struct Entry {
        let value: Double
        let date: String
    }

    private static func latest(indicator: Indicator) async throws -> [String: Entry] {
        let codes = EconomyRegion.allCases.map(\.countryCode).joined(separator: ";")
        let urlString = "\(base)/\(codes)/indicator/\(indicator.code)?format=json&per_page=200&date=2015:2026"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              root.count >= 2,
              let rows = root[1] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        var result: [String: Entry] = [:]
        for row in rows {
            guard let country = row["country"] as? [String: Any],
                  let date = row["date"] as? String,
                  let number = row["value"] as? NSNumber else { continue }

            // worldbank возвращает id страны как US/GB/XC, а ISO3 — как USA/GBR/EMU.
            let code = (row["countryiso3code"] as? String) ?? (country["id"] as? String)
            guard let code, !code.isEmpty else { continue }

            if let existing = result[code], existing.date >= date { continue }

            result[code] = Entry(value: number.doubleValue, date: date)
        }
        return result
    }

    // MARK: - Cache

    private static var cacheURL: URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("world_economy.json")
    }

    static func saveCache(_ snapshots: [String: EconomySnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func loadCache() -> [String: EconomySnapshot] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: EconomySnapshot].self, from: data)) ?? [:]
    }

    // MARK: - Формат

    static func percentText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    static func gdpText(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value >= 1_000_000_000_000 {
            return String(format: "%.1f трлн $", value / 1_000_000_000_000)
        }
        if value >= 1_000_000_000 {
            return String(format: "%.0f млрд $", value / 1_000_000_000)
        }
        return String(format: "%.0f $", value)
    }

    /// Как последние данные давят на валюту и коренные активы региона.
    static func impactText(for snapshot: EconomySnapshot) -> String {
        let growth = snapshot.growth
        let inflation = snapshot.inflation

        guard growth != nil || inflation != nil else {
            return "Показатели ещё не загружены. Обновите данные — и здесь появится вывод о влиянии на валюту и индекс региона."
        }

        var parts: [String] = []

        if let growth {
            if growth >= 2 {
                parts.append("рост экономики выше 2% поддерживает индекс и валюту региона")
            } else if growth >= 0 {
                parts.append("рост замедленный — рынок ждёт стимулов, валюта держится на ставках")
            } else {
                parts.append("спад давит на валюту, индекс живёт ожиданием разворота ставок")
            }
        }

        if let inflation {
            if inflation >= 4 {
                parts.append("высокая инфляция держит ставки жёсткими: давление на валюту вверх и на рост компаний вниз")
            } else if inflation <= 2 {
                parts.append("инфляция в норме — регулятор может смягчать, это в плюс акциям и индексу")
            } else {
                parts.append("инфляция около цели — ставки, скорее всего, останутся без резких движений")
            }
        }

        return parts.joined(separator: ". ") + "."
    }
}

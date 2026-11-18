//
//  EconomicCalendarService.swift
//  ICT Checklist
//
//  Новости Forex Factory: экономический календарь текущей и следующей недели.
//

import Foundation

enum NewsImpact: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case holiday = "Holiday"

    init(raw: String) {
        switch raw.lowercased() {
        case "high": self = .high
        case "medium": self = .medium
        case "holiday": self = .holiday
        default: self = .low
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "Высокое"
        case .medium: return "Среднее"
        case .low: return "Низкое"
        case .holiday: return "Праздник"
        }
    }

    var rank: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .holiday: return 1
        case .low: return 0
        }
    }
}

struct EconomicEvent: Identifiable, Codable {
    let title: String
    let country: String
    let date: Date
    let impact: String
    let forecast: String?
    let previous: String?
    let actual: String?

    var id: String {
        "\(title)|\(country)|\(date.timeIntervalSince1970)"
    }

    var impactKind: NewsImpact {
        NewsImpact(raw: impact)
    }

    var forecastText: String? {
        let value = (forecast ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var previousText: String? {
        let value = (previous ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var actualText: String? {
        let value = (actual ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum EconomicCalendarService {
    static let thisWeekURL = URL(string: "https://nfs.faireconomy.media/ff_calendar_thisweek.json")!
    static let nextWeekURL = URL(string: "https://nfs.faireconomy.media/ff_calendar_nextweek.json")!

    /// Загружает текущую и следующую неделю. Если одна неделя недоступна,
    /// возвращает то, что удалось получить.
    static func fetchEvents() async throws -> [EconomicEvent] {
        var events: [EconomicEvent] = []
        var firstError: Error?

        for url in [thisWeekURL, nextWeekURL] {
            do {
                let part = try await fetch(url)
                events.append(contentsOf: part)
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if events.isEmpty, let firstError {
            throw firstError
        }

        var seen = Set<String>()
        return events
            .filter { event in
                let key = event.id
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.date < $1.date }
    }

    private static func fetch(_ url: URL) async throws -> [EconomicEvent] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([EconomicEvent].self, from: data)
    }

    // MARK: - Кэш

    private static var cacheURL: URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("economic_events.json")
    }

    static func saveCache(_ events: [EconomicEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func loadCache() -> [EconomicEvent] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([EconomicEvent].self, from: data)) ?? []
    }
}

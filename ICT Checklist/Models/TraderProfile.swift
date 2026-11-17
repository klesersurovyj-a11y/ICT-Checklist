//
//  TraderProfile.swift
//  ICT Checklist
//

import Foundation
import SwiftData

enum TraderStyle: String, CaseIterable, Identifiable {
    case scalping = "Скальпинг"
    case intraday = "Интрадей"
    case swing = "Свинг"
    case position = "Среднесрочно"
    case custom = "Свой"

    var id: String { rawValue }
}

/// Профиль трейдера: его система, риск и рабочие инструменты.
@Model
final class TraderProfile {
    var name: String = ""
    var styleRaw: String = TraderStyle.intraday.rawValue
    var symbolsRaw: String = "EURUSD,GBPUSD,XAUUSD"
    var systemName: String = "TDA + Risk"
    var colorHex: Int = 0xE4E4E4
    var notes: String = ""

    var minRR: Double = 2
    var ladder1: Double = 12
    var ladder2: Double = 25
    var ladder3: Double = 50
    var maxTradesPerDay: Int = 2
    var maxDailyLossR: Double = 2

    var isActive: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "", style: TraderStyle = .intraday) {
        self.name = name
        self.styleRaw = style.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var style: TraderStyle {
        get { TraderStyle(rawValue: styleRaw) ?? .intraday }
        set { styleRaw = newValue.rawValue }
    }

    var symbols: [String] {
        get {
            symbolsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            symbolsRaw = newValue.joined(separator: ",")
        }
    }

    var initials: String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        return String(letters).uppercased()
    }

    var title: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Профиль без имени" : name
    }

    /// Переносит риск-профиль в настройки приложения.
    func apply(to settings: AppSettings) {
        settings.minRR = minRR
        settings.ladder1 = ladder1
        settings.ladder2 = ladder2
        settings.ladder3 = ladder3
        settings.maxTradesPerDay = maxTradesPerDay
        settings.maxDailyLossR = maxDailyLossR
        if !symbols.isEmpty {
            settings.symbols = symbols
        }
    }

    /// Активным остаётся только один профиль.
    static func setActive(_ profile: TraderProfile, in profiles: [TraderProfile]) {
        for item in profiles {
            item.isActive = item.persistentModelID == profile.persistentModelID
        }
    }
}

//
//  BankOverrides.swift
//  ICT Checklist
//
//  Ручные правки банковского блока: ставка, ожидания и заметка трейдера.
//  Хранятся на устройстве и перекрывают аналитическую базу по умолчанию.
//

import Foundation

enum BankOverrides {
    private static func key(_ currency: String, _ field: String) -> String {
        "bank.\(currency).\(field)"
    }

    static func rate(_ currency: String) -> String {
        UserDefaults.standard.string(forKey: key(currency, "rate")) ?? ""
    }

    static func setRate(_ value: String, currency: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(currency, "rate"))
        } else {
            UserDefaults.standard.set(trimmed, forKey: key(currency, "rate"))
        }
        touch(currency)
    }

    static func direction(_ currency: String) -> String {
        UserDefaults.standard.string(forKey: key(currency, "direction")) ?? ""
    }

    static func setDirection(_ value: String, currency: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(currency, "direction"))
        } else {
            UserDefaults.standard.set(trimmed, forKey: key(currency, "direction"))
        }
        touch(currency)
    }

    static func note(_ currency: String) -> String {
        UserDefaults.standard.string(forKey: key(currency, "note")) ?? ""
    }

    static func setNote(_ value: String, currency: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(currency, "note"))
        } else {
            UserDefaults.standard.set(trimmed, forKey: key(currency, "note"))
        }
        touch(currency)
    }

    static func updatedAt(_ currency: String) -> Date? {
        let stamp = UserDefaults.standard.double(forKey: key(currency, "updatedAt"))
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    static func hasAny(_ currency: String) -> Bool {
        !rate(currency).isEmpty || !direction(currency).isEmpty || !note(currency).isEmpty
    }

    static func clear(_ currency: String) {
        UserDefaults.standard.removeObject(forKey: key(currency, "rate"))
        UserDefaults.standard.removeObject(forKey: key(currency, "direction"))
        UserDefaults.standard.removeObject(forKey: key(currency, "note"))
        UserDefaults.standard.removeObject(forKey: key(currency, "updatedAt"))
    }

    private static func touch(_ currency: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(currency, "updatedAt"))
    }
}

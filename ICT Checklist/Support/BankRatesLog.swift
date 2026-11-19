//
//  BankRatesLog.swift
//  ICT Checklist
//
//  Журнал ревизий трёх банков: что изменилось с прошлого раза
//  и насколько данные свежие.
//

import Foundation

struct BankRevisionChange: Identifiable {
    var id: String { title }
    let title: String
    let from: String
    let to: String
}

enum BankRatesLog {
    static let staleDays = 45

    static func list(_ revisions: [BankRateRevision], currency: String) -> [BankRateRevision] {
        revisions
            .filter { $0.currency.uppercased() == currency.uppercased() }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func latest(_ revisions: [BankRateRevision], currency: String) -> BankRateRevision? {
        list(revisions, currency: currency).first
    }

    static func previous(_ revisions: [BankRateRevision], currency: String) -> BankRateRevision? {
        let items = list(revisions, currency: currency)
        return items.count > 1 ? items[1] : nil
    }

    static func ageDays(_ date: Date, now: Date = .now) -> Int {
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        return max(days, 0)
    }

    static func isStale(_ revision: BankRateRevision?, now: Date = .now) -> Bool {
        guard let revision else { return true }
        return ageDays(revision.createdAt, now: now) > staleDays
    }

    static func freshnessText(_ revision: BankRateRevision?, now: Date = .now) -> String {
        guard let revision else { return "Ревизий ещё нет" }
        let days = ageDays(revision.createdAt, now: now)
        let day = Fmt.shortDay(revision.createdAt)
        if days == 0 {
            return "Данные от \(day) · сегодня"
        }
        let word: String
        switch days % 10 {
        case 1 where days % 100 != 11:
            word = "день"
        case 2...4 where !(12...14).contains(days % 100):
            word = "дня"
        default:
            word = "дней"
        }
        return "Данные от \(day) · \(days) \(word) назад"
    }

    static func changes(
        latest: BankRateRevision?,
        previous: BankRateRevision?
    ) -> [BankRevisionChange] {
        guard let latest, let previous else { return [] }
        var result: [BankRevisionChange] = []

        append(&result, "Ставка", previous.rate, latest.rate)
        append(&result, "Ожидания", previous.expectations, latest.expectations)
        append(&result, "Через месяц", previous.oneMonth, latest.oneMonth)
        append(&result, "Квартал", previous.quarter, latest.quarter)
        append(&result, "Год", previous.year, latest.year)
        append(&result, "Сила валюты", previous.bias, latest.bias)

        return result
    }

    private static func append(
        _ list: inout [BankRevisionChange],
        _ title: String,
        _ from: String,
        _ to: String
    ) {
        let old = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, old != new else { return }
        list.append(
            BankRevisionChange(
                title: title,
                from: old.isEmpty ? "—" : old,
                to: new
            )
        )
    }

    /// Ревизия становится текущей ручной правкой банковского блока.
    static func apply(_ revision: BankRateRevision) {
        BankOverrides.setRate(revision.rate, currency: revision.currency)
        BankOverrides.setDirection(revision.expectations, currency: revision.currency)
        if !revision.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            BankOverrides.setNote(revision.note, currency: revision.currency)
        }
    }

    /// Текущая аналитическая база — первые записи журнала.
    static func baseRevisions(date: Date = .now) -> [BankRateRevision] {
        CapitalFlows.allProfiles.map { profile in
            BankRateRevision(
                createdAt: date,
                currency: profile.region.currency,
                bank: profile.policy.bank,
                rate: profile.policy.metrics.policyRate,
                expectations: profile.policy.expected.direction,
                oneMonth: profile.policy.expected.oneMonth,
                quarter: profile.policy.expected.quarter,
                year: profile.policy.expected.year,
                bias: profile.policy.bias.label,
                source: "Аналитическая база",
                note: ""
            )
        }
    }
}

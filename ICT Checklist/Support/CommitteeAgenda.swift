//
//  CommitteeAgenda.swift
//  ICT Checklist
//
//  Повестка недельного заседания: пункты собираются из данных.
//

import Foundation

enum CommitteeTarget: String, Identifiable {
    case compliance
    case advice
    case trades
    case bankRates

    var id: String { rawValue }
}

struct CommitteeItem: Identifiable {
    enum Level {
        case decision
        case watch
    }

    let id: String
    let title: String
    let detail: String
    let level: Level
    let target: CommitteeTarget?
    /// Короткий предмет решения для протокола.
    let subject: String
}

enum CommitteeAgenda {
    static func weekStart(_ date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func weekLabel(_ date: Date = .now, calendar: Calendar = .current) -> String {
        let start = weekStart(date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let first = calendar.component(.day, from: start)
        let last = calendar.component(.day, from: end)
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "ru_RU")
        monthFormatter.dateFormat = "LLLL"
        let month = monthFormatter.string(from: end).lowercased()
        return "\(first)–\(last) \(month)"
    }

    static func build(
        trades: [Trade],
        accounts: [TradingAccount],
        mandates: [FundMandate],
        hypotheses: [AdviceHypothesis],
        revisions: [BankRateRevision],
        protocols: [CommitteeProtocol],
        stressLastRun: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [CommitteeItem] {
        var items: [CommitteeItem] = []
        let start = weekStart(now, calendar: calendar)

        // 1. Нарушения мандата за неделю.
        let compliance = MandateCompliance.report(
            trades: trades,
            accounts: accounts,
            mandates: mandates,
            now: now,
            calendar: calendar
        )
        let weekViolations = compliance.violations.filter { $0.date >= start }
        if let first = weekViolations.first {
            let cost = weekViolations.reduce(0) { $0 + $1.r }
            items.append(
                CommitteeItem(
                    id: "compliance",
                    title: "Нарушен лимит \(first.limit.rawValue.lowercased()): \(first.symbol) \(first.detail)",
                    detail: "Комплаенс · \(Fmt.deals(weekViolations.count)) · \(Fmt.r(cost))",
                    level: .decision,
                    target: .compliance,
                    subject: "лимит \(first.limit.rawValue.lowercased())"
                )
            )
        }

        // 2. Гипотезы советов с истёкшим сроком.
        let due = hypotheses.filter { hypothesis in
            hypothesis.status == .testing
                && AdviceJournal.progress(for: hypothesis, trades: trades).isDue
        }
        if let first = due.first {
            items.append(
                CommitteeItem(
                    id: "advice",
                    title: due.count == 1
                        ? "Гипотеза набрала срок"
                        : "\(due.count) \(due.count < 5 ? "гипотезы" : "гипотез") набрали срок",
                    detail: "Советы · проверка после \(AdviceJournal.checkAfterTrades(first)) сделок",
                    level: .decision,
                    target: .advice,
                    subject: "гипотезу «\(first.title.isEmpty ? "без названия" : first.title)»"
                )
            )
        }

        // 3. Сделки без разбора.
        let unreviewed = trades.filter { trade in
            guard trade.result != .open, trade.review == nil else { return false }
            let date = trade.closedAt ?? trade.tradingDay
            return date < start
        }
        if !unreviewed.isEmpty {
            items.append(
                CommitteeItem(
                    id: "reviews",
                    title: "\(Fmt.deals(unreviewed.count)) без разбора",
                    detail: "Разборы · старше 7 дней",
                    level: .decision,
                    target: .trades,
                    subject: "разбор сделок"
                )
            )
        }

        // 4. Ревизии банков старше 45 дней.
        if let stale = CapitalFlows.allProfiles.first(where: { profile in
            let latest = BankRatesLog.latest(revisions, currency: profile.region.currency)
            return BankRatesLog.isStale(latest, now: now)
        }) {
            let latest = BankRatesLog.latest(revisions, currency: stale.region.currency)
            items.append(
                CommitteeItem(
                    id: "bank-\(stale.region.currency)",
                    title: "Ревизия \(stale.policy.bank) старше 45 дней",
                    detail: latest == nil
                        ? "Ставки · ревизий ещё нет"
                        : "Ставки · последняя \(Fmt.shortDay(latest!.createdAt))",
                    level: .watch,
                    target: .bankRates,
                    subject: "ревизию \(stale.policy.bank)"
                )
            )
        }

        // 5. Стресс-тест не обновлялся.
        let stressAge = stressLastRun.map { BankRatesLog.ageDays($0, now: now) }
        if stressAge == nil || (stressAge ?? 0) > 14 {
            items.append(
                CommitteeItem(
                    id: "stress",
                    title: stressAge == nil
                        ? "Стресс-тест не обновлялся"
                        : "Стресс-тест не обновлялся \(stressWeeks(stressAge ?? 0))",
                    detail: "Стресс-тесты · давление на книгу",
                    level: .watch,
                    target: nil,
                    subject: "стресс-тест книги"
                )
            )
        }

        // 6. Отклонения в атрибуции по сетапам.
        let monthStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        var recent: [Trade] = []
        for trade in trades {
            guard trade.result != .open else { continue }
            let date = trade.closedAt ?? trade.tradingDay
            if date >= monthStart {
                recent.append(trade)
            }
        }
        if let item = setupDeviation(recent) {
            items.append(item)
        }

        return items
    }

    private static func setupDeviation(_ trades: [Trade]) -> CommitteeItem? {
        let grouped = Dictionary(grouping: trades, by: { $0.setupName })
        var candidates: [(name: String, count: Int, r: Double)] = []
        for (name, list) in grouped where !name.isEmpty {
            var total = 0.0
            for trade in list {
                total += trade.actualR
            }
            candidates.append((name: name, count: list.count, r: total))
        }

        let weak = candidates.filter { candidate in
            candidate.count >= 3 && candidate.r < -0.05
        }
        guard let worst = weak.min(by: { $0.r < $1.r }) else { return nil }

        return CommitteeItem(
            id: "setup-\(worst.name)",
            title: "Вклад сетапа «\(worst.name)» упал до \(Fmt.r(worst.r))",
            detail: "Атрибуция · \(Fmt.deals(worst.count)) за 30 дней",
            level: .watch,
            target: .trades,
            subject: "вес сетапа «\(worst.name)»"
        )
    }

    private static func stressWeeks(_ days: Int) -> String {
        let weeks = max(days / 7, 2)
        switch weeks % 10 {
        case 1 where weeks % 100 != 11:
            return "\(weeks) неделю"
        case 2...4 where !(12...14).contains(weeks % 100):
            return "\(weeks) недели"
        default:
            return "\(weeks) недель"
        }
    }
}

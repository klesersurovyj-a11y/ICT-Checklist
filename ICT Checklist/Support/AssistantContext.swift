//
//  AssistantContext.swift
//  ICT Checklist
//

import Foundation
import SwiftData

/// Сжатый снимок базы приложения, который ассистент получает в каждом запросе.
enum AssistantContext {
    struct Snapshot {
        let text: String
        let tradeCount: Int
        let planCount: Int
        let systemName: String
    }

    static func build(context: ModelContext) -> Snapshot {
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
        let blueprints = (try? context.fetch(FetchDescriptor<SystemBlueprint>())) ?? []
        let profiles = (try? context.fetch(FetchDescriptor<TraderProfile>())) ?? []
        let trades = (try? context.fetch(
            FetchDescriptor<Trade>(sortBy: [SortDescriptor(\Trade.entryDate, order: .reverse)])
        )) ?? []
        let plans = (try? context.fetch(
            FetchDescriptor<TradePlan>(sortBy: [SortDescriptor(\TradePlan.day, order: .reverse)])
        )) ?? []
        let notes = (try? context.fetch(
            FetchDescriptor<BrainNote>(sortBy: [SortDescriptor(\BrainNote.updatedAt, order: .reverse)])
        )) ?? []
        let ladderState = (try? context.fetch(FetchDescriptor<RiskLadderState>()))?.first

        let blueprint = blueprints.first
        let systemName = blueprint?.name ?? "TDA + Risk"

        var lines: [String] = []
        lines.append("ДАННЫЕ ПРИЛОЖЕНИЯ на \(Fmt.day(.now))")

        if let active = profiles.first(where: { $0.isActive }) {
            lines.append(
                "АКТИВНЫЙ ПРОФИЛЬ: \(active.title) · \(active.style.rawValue) · система \(active.systemName) · minRR \(Fmt.rr(active.minRR)) · риск \(Fmt.money(active.ladder1)) · символы \(profileSymbols(active))"
            )
        } else if profiles.isEmpty {
            lines.append("АКТИВНЫЙ ПРОФИЛЬ: не выбран")
        } else {
            lines.append("АКТИВНЫЙ ПРОФИЛЬ: не выбран, в базе \(profiles.count) профилей")
        }

        if let settings {
            let limits = settings.dailyLimitsEnabled
                ? "вкл: \(settings.maxTradesPerDay) сделок в день, лимит \(Fmt.r(-settings.maxDailyLossR))"
                : "выкл"
            lines.append(
                "НАСТРОЙКИ: minRR \(Fmt.rr(settings.minRR)) · лэддер \(Fmt.money(settings.ladder1)) / \(Fmt.money(settings.ladder2)) / \(Fmt.money(settings.ladder3)) · цикл \(Fmt.clock(hour: settings.cycleStartHour, minute: settings.cycleStartMinute))–\(Fmt.clock(hour: settings.cycleEndHour, minute: settings.cycleEndMinute)) · лимиты дня \(limits) · символы \(settings.symbols.joined(separator: ", "))"
            )
        }

        if let blueprint {
            let stages = blueprint.stages.filter(\.isEnabled)
            if !stages.isEmpty {
                let list = stages
                    .map { "\($0.title) — \($0.rule.isEmpty ? $0.detail : $0.rule)" }
                    .joined(separator: " → ")
                lines.append("СИСТЕМА «\(blueprint.name)»: \(list)")
            }
        }

        if let ladderState {
            lines.append(
                "РИСК-ЛЭДДЕР: ступень \(min(max(ladderState.stepIndex, 0), 2) + 1) из 3 · накоплено \(Fmt.r(ladderState.accumulatedR))"
            )
        }

        let closed = trades.filter { $0.result != .open }
        let wins = closed.filter { $0.actualR > 0.05 }.count
        let totalR = closed.reduce(0) { $0 + $1.actualR }
        let averageR = closed.isEmpty ? 0 : totalR / Double(closed.count)
        let winRate = closed.isEmpty ? 0 : Int((Double(wins) / Double(closed.count) * 100).rounded())

        lines.append(
            "СДЕЛКИ: всего \(trades.count), закрыто \(closed.count), win \(winRate)%, сумма \(Fmt.r(totalR)), средняя \(String(format: "%+.2f", averageR))R"
        )

        let bySymbol = Dictionary(grouping: closed, by: \.symbol)
            .map { symbol, list in (symbol, list.count, list.reduce(0) { $0 + $1.actualR }) }
            .sorted { $0.2 > $1.2 }
        if !bySymbol.isEmpty {
            let list = bySymbol.prefix(5)
                .map { "\($0.0) \($0.1) сделок \(Fmt.r($0.2))" }
                .joined(separator: " · ")
            lines.append("ПО СИМВОЛАМ: \(list)")
        }

        var tagTotals: [String: (count: Int, total: Double)] = [:]
        for trade in closed {
            for tag in trade.tags {
                let name = tag.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                let current = tagTotals[name] ?? (0, 0)
                tagTotals[name] = (current.count + 1, current.total + trade.actualR)
            }
        }
        if !tagTotals.isEmpty {
            let list = tagTotals
                .sorted { $0.value.total > $1.value.total }
                .prefix(6)
                .map { "\($0.key) \($0.value.count) / \(Fmt.r($0.value.total))" }
                .joined(separator: " · ")
            lines.append("ПО ТЕГАМ: \(list)")
        }

        if !trades.isEmpty {
            lines.append("ПОСЛЕДНИЕ СДЕЛКИ:")
            for trade in trades.prefix(15) {
                var line = "\(Fmt.dayMonth(trade.tradingDay)) \(trade.symbol) \(trade.direction.rawValue) \(trade.result.rawValue) \(Fmt.r(trade.actualR)) · план \(Fmt.rr(trade.plannedRR)) · ступень \(min(trade.ladderStepIndex, 2) + 1)"
                if !trade.tags.isEmpty {
                    line += " · теги: \(trade.tags.joined(separator: ", "))"
                }
                if !trade.note.isEmpty {
                    line += " · заметка: \(short(trade.note))"
                }
                if trade.memoVerdict != .none {
                    line += " · комитет: \(trade.memoVerdict.title.lowercased())"
                }
                lines.append(line)
            }
        }

        let openTrades = trades.filter { $0.result == .open }
        if !openTrades.isEmpty {
            let list = openTrades.prefix(5)
                .map { "\($0.symbol) \($0.direction.rawValue) вход \(Fmt.price($0.entry)) SL \(Fmt.price($0.currentStop)) TP \(Fmt.price($0.takeProfit))" }
                .joined(separator: " · ")
            lines.append("ОТКРЫТЫЕ СДЕЛКИ: \(list)")
        }

        if !plans.isEmpty {
            lines.append("ПЛАНЫ:")
            for plan in plans.prefix(5) {
                let missing = PlanCheck.allCases
                    .filter { !plan.checkedKeys.contains($0) }
                    .map(\.title)
                var line = "\(Fmt.dayMonth(plan.day)) \(plan.symbol) \(plan.direction.rawValue) — \(plan.result.rawValue) · чек-лист \(plan.checkedCount)/\(PlanCheck.allCases.count)"
                if !missing.isEmpty {
                    line += " · не отмечено: \(missing.prefix(4).joined(separator: ", "))"
                }
                if !plan.thesis.isEmpty {
                    line += " · тезис: \(short(plan.thesis))"
                }
                lines.append(line)
            }
        }

        if !notes.isEmpty {
            let list = notes.prefix(5).map { note in
                "\(note.kind.short)\(note.kind.usesStatus ? " [\(note.status.rawValue)]" : ""): \(note.displayTitle)"
            }.joined(separator: " · ")
            lines.append("SECOND BRAIN (последние записи): \(list)")
        }
        let errors = (try? context.fetch(
            FetchDescriptor<ErrorNote>(sortBy: [SortDescriptor(\ErrorNote.updatedAt, order: .reverse)])
        )) ?? []
        if !errors.isEmpty {
            let list = errors.prefix(6).map { note in
                let cost = note.sortedTrades.reduce(0) { $0 + $1.actualR }
                return "\(note.title) [\(note.status.rawValue)] \(note.trades.count) сделок \(Fmt.r(cost))"
            }.joined(separator: " · ")
            lines.append("ОШИБКИ: всего \(errors.count) · \(list)")
        }

        let missingReviews = closed.filter { $0.review == nil }.count
        lines.append("РАЗБОРЫ: не заполнено \(missingReviews) из \(closed.count) закрытых")

        let bySystem = closed.filter { $0.checklistComplete }.count
        lines.append("ДИСЦИПЛИНА: чек-лист сделки закрыт у \(bySystem) из \(closed.count) закрытых")

        let memoApproved = closed.filter { $0.memoVerdict == .approved }.count
        let memoRejected = closed.filter { $0.memoVerdict == .rejected }.count
        let memoOpen = trades.filter { $0.result == .open && $0.memoVerdict == .approved }.count
        if memoApproved + memoRejected > 0 || memoOpen > 0 {
            lines.append(
                "КОМИТЕТ: утверждено \(memoApproved) закрытых · отклонено \(memoRejected) · утверждено в открытых \(memoOpen)"
            )
        }

        if !plans.isEmpty {
            let incomplete = plans.filter { !$0.isChecklistComplete }.count
            lines.append("ДИСЦИПЛИНА ПЛАНОВ: \(plans.count) планов, неполный чек-лист у \(incomplete)")
        }

        let window = CapitalFlows.rebalancingWindow()
        lines.append("БАНКИ И ПОТОКИ:")
        for item in CapitalFlows.allProfiles {
            lines.append(
                "\(item.region.rawValue) · \(item.policy.bank) · \(item.biasTitle) · ставка \(item.policy.metrics.policyRate) · ожидания: \(item.policy.expected.direction) · через месяц: \(item.policy.expected.oneMonth) · расхождение: \(item.policy.divergenceTitle) · сила валюты: \(item.policy.bias.label) · для валюты: \(item.policy.currencyEffect)"
            )
        }
        lines.append("ОКНО РЕБАЛАНСА: \(window.label)")

        lines.append("ЗАПИСЕЙ В БАЗЕ ЗНАНИЙ: \(notes.count)")

        return Snapshot(
            text: lines.joined(separator: "\n"),
            tradeCount: trades.count,
            planCount: plans.count,
            systemName: systemName
        )
    }

    private static func profileSymbols(_ profile: TraderProfile) -> String {
        let symbols = profile.symbols
        return symbols.isEmpty ? "не заданы" : symbols.joined(separator: ", ")
    }

    private static func short(_ text: String, limit: Int = 90) -> String {
        let single = text.replacingOccurrences(of: "\n", with: " ")
        let trimmed = single.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit)) + "…"
    }
}

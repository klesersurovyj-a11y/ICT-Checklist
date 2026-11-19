//
//  TradeSnapshotCard.swift
//  ICT Checklist
//
//  Замороженный снимок входа: что было на экране в момент сделки.
//

import SwiftUI

struct TradeSnapshotCard: View {
    let snapshot: TradeSnapshot
    let shots: [TradeShot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            SummaryTable(items: coreItems)

            if let cycle = snapshot.cycle {
                cycleSection(cycle)
            }

            if !snapshot.banks.isEmpty {
                banksSection
            }

            if !snapshot.rebalancing.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    Text(snapshot.rebalancing)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
            }

            textSection
            shotsSection
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SectionLabel(text: "Снимок на входе")
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("ЗАМОРОЖЕН")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accent.opacity(0.14)))
            }

            Text("\(Fmt.shortDay(snapshot.createdAt)) · \(Fmt.time(snapshot.createdAt)) · \(snapshot.symbol) \(snapshot.direction)")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Numbers

    private var coreItems: [SummaryItem] {
        var items: [SummaryItem] = [
            SummaryItem(title: "Вход", value: Fmt.price(snapshot.entry)),
            SummaryItem(title: "SL", value: Fmt.price(snapshot.stop), tint: Theme.red),
            SummaryItem(title: "TP", value: Fmt.price(snapshot.takeProfit), tint: Theme.green),
            SummaryItem(title: "Риск", value: Fmt.money(snapshot.riskUSD)),
            SummaryItem(title: "RR", value: Fmt.rr(snapshot.plannedRR))
        ]

        if !snapshot.setupName.isEmpty {
            items.append(SummaryItem(title: "Сетап", value: snapshot.setupName))
        }

        if let ladder = snapshot.ladder {
            let amount = ladder.levels.indices.contains(ladder.step)
                ? ladder.levels[ladder.step]
                : snapshot.riskUSD
            items.append(
                SummaryItem(
                    title: "Ступень",
                    value: "\(ladder.step + 1) из 3 · \(Fmt.money(amount))",
                    tint: Theme.blue
                )
            )
            items.append(
                SummaryItem(
                    title: "Накоплено",
                    value: Fmt.r(ladder.accumulatedR),
                    tint: ladder.accumulatedR >= 0 ? Theme.green : Theme.red
                )
            )
        }

        if let limits = snapshot.limits {
            items.append(
                SummaryItem(
                    title: "Лимиты дня",
                    value: limits.enabled
                        ? "\(limits.tradesToday)/\(limits.maxTrades) сделок · \(Fmt.r(limits.closedTodayR)) из \(Fmt.r(-limits.maxDailyLossR))"
                        : "выключены",
                    tint: limits.enabled ? Theme.orange : Theme.textSecondary
                )
            )
        }

        return items
    }

    private func cycleSection(_ cycle: CycleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Цикл дня")
            SummaryTable(items: cycleItems(cycle))
        }
    }

    private func cycleItems(_ cycle: CycleSnapshot) -> [SummaryItem] {
        var items: [SummaryItem] = [
            SummaryItem(title: "Направление", value: cycle.direction),
            SummaryItem(title: "Поток", value: cycle.trend)
        ]

        if let zone = cycle.zone {
            items.append(SummaryItem(title: "Зона", value: zone))
        }

        if let high = cycle.drHigh, let low = cycle.drLow, high > low {
            items.append(SummaryItem(title: "DR", value: "\(Fmt.price(low))–\(Fmt.price(high))"))
        }

        if let pointA = cycle.pointA {
            items.append(SummaryItem(title: "Point A", value: Fmt.price(pointA)))
        }

        if let pointB = cycle.pointB {
            let type = cycle.pointBType.map { " · \($0)" } ?? ""
            items.append(SummaryItem(title: "Point B", value: Fmt.price(pointB) + type))
        }

        if !cycle.keyLevels.isEmpty {
            let list = cycle.keyLevels
                .map { "\($0.title) \(Fmt.price($0.price))" }
                .joined(separator: " · ")
            items.append(SummaryItem(title: "Уровни", value: list))
        }

        items.append(
            SummaryItem(
                title: "Подтверждения",
                value: "\(cycle.confirmations)/\(cycle.confirmationsTotal)",
                tint: cycle.confirmations >= 4 ? Theme.green : Theme.textPrimary
            )
        )

        if let rr = cycle.rr {
            items.append(SummaryItem(title: "RR цикла", value: Fmt.rr(rr)))
        }

        if cycle.stopDay {
            items.append(SummaryItem(title: "STOP DAY", value: "включён", tint: Theme.red))
        }

        return items
    }

    // MARK: - Banks

    private var banksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Банки и ожидания")

            ForEach(snapshot.banks, id: \.currency) { bank in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(bank.bank)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(bank.currency)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer(minLength: 4)
                        Text(bank.bias)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text("Ставка \(bank.rate)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Ожидания: \(bank.expectations.lowercased()) · месяц \(bank.oneMonth) · квартал \(bank.quarter) · год \(bank.year)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Расхождение: \(bank.divergence)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }

    // MARK: - Your text

    @ViewBuilder
    private var textSection: some View {
        let text = snapshot.text

        if hasText {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Что вы знали")

                block("Тезис", text.thesis)
                block("Что в цене", text.pricedIn)
                block("Сценарии", text.scenarios)
                block("Инвалидация", text.invalidation)
                block("Ответ команде", text.answers)
                block("Заметка", text.note)

                if !text.tags.isEmpty {
                    Text(text.tags.joined(separator: " · "))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                if !text.checklist.isEmpty {
                    let checked = text.checklist.filter(\.checked).count
                    Text("Чек-лист \(checked)/\(text.checklist.count)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(checked == text.checklist.count ? Theme.green : Theme.orange)
                }
            }
        }
    }

    private var hasText: Bool {
        let text = snapshot.text
        return !text.thesis.isEmpty
            || !text.pricedIn.isEmpty
            || !text.scenarios.isEmpty
            || !text.invalidation.isEmpty
            || !text.answers.isEmpty
            || !text.note.isEmpty
            || !text.tags.isEmpty
    }

    @ViewBuilder
    private func block(_ title: String, _ value: String) -> some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.textTertiary)
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Screenshots

    private var shotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Скриншоты на входе")

            if shots.isEmpty {
                Text(snapshot.shotCount > 0 ? "Снимки к сделке не сохранились" : "На входе скриншотов не было")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shots) { shot in
                            ShotThumbnail(shot: shot, size: 74)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }
}

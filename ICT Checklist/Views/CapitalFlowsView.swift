//
//  CapitalFlowsView.swift
//  ICT Checklist
//
//  Разбор потоков капитала: ставка и баланс банка, реакция валюты,
//  ребалансы фондов, хедж выручки и трендовые фонды.
//

import SwiftUI

struct CapitalFlowsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var region: EconomyRegion
    @State private var rateDraft = ""
    @State private var directionDraft = ""
    @State private var noteDraft = ""

    init(initialRegion: EconomyRegion = .usa) {
        _region = State(initialValue: initialRegion)
    }

    private var profile: CapitalFlowProfile {
        CapitalFlows.profile(for: region)
    }

    private var window: (label: String, active: Bool) {
        CapitalFlows.rebalancingWindow()
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    windowCard
                        .reveal(.zoom, 1)

                    GlassSegmented(
                        options: EconomyRegion.allCases,
                        selection: $region,
                        label: { $0.rawValue }
                    )
                    .reveal(.blur, 2)

                    editCard
                        .reveal(.rise, 2)

                    layersCard
                        .reveal(.rise, 3)

                    policyCard
                        .reveal(.rise, 3)

                    motiveCard
                        .reveal(.rise, 3)

                    metricsCard
                        .reveal(.rise, 4)

                    expectedCard
                        .reveal(.rise, 4)

                    divergenceCard
                        .reveal(.rise, 5)

                    biasCard
                        .reveal(.rise, 5)

                    reactionCard
                        .reveal(.rise, 4)

                    pairsCard
                        .reveal(.rise, 5)

                    comparisonCard
                        .reveal(.rise, 5)

                    flowsCard
                        .reveal(.rise, 6)

                    trendCard
                        .reveal(.rise, 6)

                    datesCard
                        .reveal(.rise, 7)

                    frameworkCard
                        .reveal(.rise, 7)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .onAppear { loadOverrides() }
        .onChange(of: region) { _, _ in loadOverrides() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .glassCircle()
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Мировая карта · Потоки")
                ScreenTitle(text: "Кто двигает валюту")
                Text("Мотив государства, реакция банка и след в цене \(profile.region.currency)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .windIn(delay: 0.8)
            }
        }
    }

    // MARK: - Window

    private var windowCard: some View {
        let tint = window.active ? Theme.orange : Theme.textTertiary
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(window.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(
                    window.active
                        ? "В эти дни календарные потоки ребаланса перебивают обычную логику: движение может идти против тренда и затихать сразу после закрытия периода."
                        : "Вне окна ребаланса валюту двигают ставка, хедж выручки и тренд, а не календарь."
                )
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Policy

    private var policyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "ДКП · \(profile.policy.bank)")
                Spacer(minLength: 4)
                Text(profile.biasTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(profile.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(profile.tint.opacity(0.14)))
            }

            Text(profile.policy.stance)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("ДЛЯ ВАЛЮТЫ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(profile.tint)
                Text(profile.policy.currencyEffect)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(profile.tint.opacity(0.08))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Motive

    private var motiveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Мотив банка")
            Text(profile.policy.motive)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Мотив важнее решения: рынок двигает не ставка, а смена ожиданий о следующем шаге.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        let metrics = profile.policy.metrics
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Ставка, баланс, инфляция")

            metricRow("Ставка", rateText, tint: profile.tint)
            divider
            metricRow("Следующий шаг", metrics.nextMove, tint: Theme.textPrimary)
            divider
            metricRow("Баланс", metrics.balanceSheet)
            divider
            metricRow("Базовая инфляция", metrics.coreInflation)
            divider
            metricRow("Рынок труда", metrics.labour)
            divider
            metricRow("Рост", metrics.growth)
            divider
            metricRow("Реальная ставка", metrics.realRate, tint: profile.tint)

            Text("Ставки и оценки — ориентир на момент сборки, перед сделкой сверяйте с календарём ЦБ.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var divider: some View {
        Divider().overlay(Theme.hairline)
    }

    private func metricRow(_ title: String, _ value: String, tint: Color = Theme.textSecondary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 112, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Your edits

    private var rateText: String {
        let code = profile.region.currency
        let override = BankOverrides.rate(code)
        return override.isEmpty ? profile.policy.metrics.policyRate : override
    }

    private var directionText: String {
        let code = profile.region.currency
        let override = BankOverrides.direction(code)
        return override.isEmpty ? profile.policy.expected.direction : override
    }

    private func loadOverrides() {
        let code = profile.region.currency
        rateDraft = BankOverrides.rate(code)
        directionDraft = BankOverrides.direction(code)
        noteDraft = BankOverrides.note(code)
    }

    private var editCard: some View {
        let code = profile.region.currency
        let updated = BankOverrides.updatedAt(code)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Ваша правка")
                Spacer(minLength: 4)
                Text(directionText)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(profile.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(profile.tint.opacity(0.14)))
            }

            Text("Банковский блок — аналитическая база, а не поток. Впишите актуальные цифры и свои выводы, они сохранятся на устройстве и перекроют текст по умолчанию.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            SingleLineField(
                placeholder: "Ставка, например 3,75–4,00%",
                text: $rateDraft
            )
            .onChange(of: rateDraft) { _, newValue in
                BankOverrides.setRate(newValue, currency: code)
            }

            SingleLineField(
                placeholder: "Ожидания: пауза, мягче, жёстче",
                text: $directionDraft
            )
            .onChange(of: directionDraft) { _, newValue in
                BankOverrides.setDirection(newValue, currency: code)
            }

            GlassNoteField(
                placeholder: "Моя заметка по банку и валюте…",
                text: $noteDraft,
                limit: 400,
                lines: 2...5
            )
            .onChange(of: noteDraft) { _, newValue in
                BankOverrides.setNote(newValue, currency: code)
            }

            if let updated {
                HStack(spacing: 6) {
                    Text("Изменено \(Fmt.dayMonth(updated))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)

                    Spacer(minLength: 6)

                    Button {
                        BankOverrides.clear(code)
                        rateDraft = ""
                        directionDraft = ""
                        noteDraft = ""
                        Haptics.warning()
                    } label: {
                        Text("Сбросить")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Four layers

    private var layersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Четыре слоя")

            frameworkRow(
                index: "1",
                title: "Current Policy",
                text: "Действующая политика: \(rateText). \(profile.policy.stance)"
            )
            frameworkRow(
                index: "2",
                title: "Expected Policy",
                text: "Ожидаемая траектория: \(directionText.lowercased()). \(profile.policy.expected.oneMonth)"
            )
            frameworkRow(
                index: "3",
                title: "Policy Divergence",
                text: profile.policy.divergenceTitle
            )
            frameworkRow(
                index: "4",
                title: "Currency Bias",
                text: "\(profile.policy.bias.label) — \(profile.region.currency)"
            )

            Text("Сначала смотрите на действующую политику, потом на ожидания, затем на расхождение между банками. Валюта сильна там, где ожидания жёстче, чем у соседей.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Expected path

    private var expectedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel(text: "Ожидаемая траектория")
                Spacer(minLength: 4)
                Text(directionText)
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(profile.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(profile.tint.opacity(0.14)))
            }

            horizonRow("ЧЕРЕЗ МЕСЯЦ", profile.policy.expected.oneMonth)
            divider
            horizonRow("ЧЕРЕЗ КВАРТАЛ", profile.policy.expected.quarter)
            divider
            horizonRow("ЧЕРЕЗ ГОД", profile.policy.expected.year)

            Text("Ожидания — это то, что уже в цене. Движение даёт расхождение между ожиданием и реальным решением, а не сама траектория.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func horizonRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Divergence

    private var divergenceCard: some View {
        let profiles = CapitalFlows.allProfiles
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Policy divergence · расхождение")

            Text(profile.policy.divergence)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.hairline)

            ForEach(profiles) { item in
                HStack(spacing: 8) {
                    Text(item.region.currency)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 38, alignment: .leading)
                    Text(item.biasTitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(item.policy.bias.label)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(item.policy.bias.tint)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Bias

    private var biasCard: some View {
        let bias = profile.policy.bias
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel(text: "Currency bias · \(profile.region.currency)")
                Spacer(minLength: 4)
                Text(bias.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(bias.tint)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(bias.tint.opacity(0.14)))
            }

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < bias.score + 3 ? bias.tint : Color.white.opacity(0.10))
                        .frame(height: 5)
                }
            }

            Text(bias.text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Фундаментальная сила — это ставка, поток капитала и баланс экономики вместе. Она задаёт направление, но не тайминг.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Reaction

    private var reactionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Реакция валюты")

            ForEach(profile.policy.reactions) { reaction in
                reactionRow(reaction)
            }

            Text("Реакция типичная, а не гарантированная: сила зависит от того, насколько событие уже заложено в цену.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func reactionRow(_ reaction: CurrencyReaction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(reaction.direction.tint.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: reaction.direction.symbolName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(reaction.direction.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(reaction.event)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text("\(reaction.direction.title) · \(reaction.strength)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(reaction.direction.tint)
                        .lineLimit(1)
                }
                Text(reaction.comment)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Pairs

    private var pairsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Пары и кросс-курсы")
            Text(profile.policy.pairsNote)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        let profiles = CapitalFlows.allProfiles
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Три банка рядом")

            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.policy.bank)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(item.region.currency)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(width: 96, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.biasTitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(item.tint)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.policy.metrics.policyRate.replacingOccurrences(of: " · ориентир", with: ""))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)

                if index < profiles.count - 1 {
                    Divider().overlay(Theme.hairline)
                }
            }

            Text("Разница ставок и ожиданий между этими тремя банками и есть основной источник движения валютных пар.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Flows

    private var flowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Крупные деньги")

            flowRow(
                icon: "building.columns",
                title: "Пенсионные фонды · ребаланс",
                text: profile.flows.pension,
                tint: Theme.lavender
            )

            Divider().overlay(Theme.hairline)

            flowRow(
                icon: "shippingbox",
                title: "Внешняя торговля · хедж выручки",
                text: profile.flows.trade,
                tint: Theme.blue
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func flowRow(icon: String, title: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SectionLabel(text: "СТА · Trend following")
                Spacer(minLength: 4)
                Text("ХЕДЖ В ТРЕНДЕ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.green.opacity(0.14)))
            }

            Text(profile.flows.trend)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Тренд добавляет ликвидность в сторону движения: пока он цел, поток работает на него; после разворота тот же поток ускоряет выход.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Dates

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Ключевые даты")

            ForEach(profile.policy.dates) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(profile.tint)
                        .frame(width: 18)

                    Text(item.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 150, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.cadence)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Framework

    private var frameworkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Как это читать")

            frameworkRow(index: "1", title: "Мотив", text: "Что государство и банк хотят получить: инфляцию, рост или дешёвый экспорт.")
            frameworkRow(index: "2", title: "Реакция фондов", text: "Пенсионные фонды ребалансируют календарно, корпорации хеджируют выручку, трендовые фонды добавляют в движении.")
            frameworkRow(index: "3", title: "След в цене", text: "Постоянный хедж и ребаланс поглощают движение без новостей, а тренд его ускоряет.")

            Divider().overlay(Theme.hairline)

            VStack(alignment: .leading, spacing: 3) {
                Text("ЧТО ОТМЕНИТ СЦЕНАРИЙ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.orange)
                Text(profile.policy.invalidation)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func frameworkRow(index: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.background)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

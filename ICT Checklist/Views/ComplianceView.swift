//
//  ComplianceView.swift
//  ICT Checklist
//
//  Комплаенс: каждая сделка против активной версии мандата.
//

import SwiftUI
import SwiftData

struct ComplianceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \FundMandate.version, order: .reverse) private var mandates: [FundMandate]

    @State private var showAllViolations = false
    @State private var showTrades = false
    @State private var showMandateEditor = false
    @State private var openedTrade: Trade?

    private var activeMandate: FundMandate? {
        FundMandate.active(in: mandates)
    }

    private var report: ComplianceReport {
        MandateCompliance.report(trades: trades, accounts: accounts, mandates: mandates)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)

                    if report.hasMandate {
                        summaryCard
                            .reveal(.zoom, 1)
                        limitsCard
                            .reveal(.rise, 2)
                        violationsCard
                            .reveal(.rise, 3)
                        tradesButton
                            .reveal(.rise, 4)
                        mandateInfoCard
                            .reveal(.rise, 5)
                    } else {
                        noMandateCard
                            .reveal(.rise, 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showAllViolations) {
            AllViolationsSheet(report: report) { trade in
                showAllViolations = false
                openedTrade = trade
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showTrades) {
            ComplianceTradesSheet(
                trades: uniqueTrades,
                onOpen: { trade in
                    showTrades = false
                    openedTrade = trade
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showMandateEditor) {
            MandateEditorSheet(version: FundMandate.nextVersion(in: mandates))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $openedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: [])
        }
    }

    private var topViolations: [ComplianceViolation] {
        Array(report.violations.prefix(3))
    }

    private var violationTrades: [Trade] {
        report.violations.compactMap(\.trade)
    }

    private var openedTrades: [Trade] {
        trades.filter { $0.result == .open }
    }

    private var uniqueTrades: [Trade] {
        var seen = Set<String>()
        var result: [Trade] = []
        for trade in violationTrades + openedTrades {
            let key = String(trade.persistentModelID.hashValue)
            if seen.insert(key).inserted {
                result.append(trade)
            }
        }
        return result
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Назад")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: headerLabel)
            ScreenTitle(text: "Комплаенс")
            Text(
                report.hasMandate
                    ? "\(report.violations.count) \(violationWord(report.violations.count)) · \(Fmt.r(report.totalR)) за всё время"
                    : "Проверки включатся, когда появится мандат"
            )
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerLabel: String {
        guard let mandate = activeMandate else {
            return "Система · мандат не задан"
        }
        let date = mandate.createdAt
        return "Система · мандат v\(mandate.version) · \(Fmt.shortDay(date))"
    }

    private func violationWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "нарушение" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "нарушения" }
        return "нарушений"
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Нарушений")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(report.violations.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Стоимость")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.r(report.totalR))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(.vertical, 14)

            Divider()
                .overlay(Theme.hairline)

            Text("Проверяется по активной версии мандата")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Limits

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Лимиты")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(report.rows) { row in
                limitRow(row)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func limitRow(_ row: MandateUsageRow) -> some View {
        let tint = row.exceeded ? Theme.red : (row.ratio >= 0.8 ? Theme.orange : Theme.green)
        let share = min(max(row.ratio, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(row.limit.rawValue)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 6)

                Text(row.valueText)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(row.excessText)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(row.exceeded ? Theme.red : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            (row.exceeded ? Theme.red : Theme.textTertiary).opacity(0.12)
                        )
                    )
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, proxy.size.width * CGFloat(share)))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Violations

    private var violationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Нарушения")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Button {
                    showAllViolations = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 4) {
                        Text("Все")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if topViolations.isEmpty {
                Text("Нарушений нет: сделки укладываются в активную версию мандата.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(topViolations.enumerated()), id: \.element.id) { index, violation in
                    Button {
                        if let trade = violation.trade {
                            openedTrade = trade
                        } else {
                            showAllViolations = true
                        }
                        Haptics.tap()
                    } label: {
                        violationRow(violation)
                    }
                    .buttonStyle(.plain)

                    if index < topViolations.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func violationRow(_ violation: ComplianceViolation) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.red.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(violation.limit.rawValue)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(violation.symbol) · \(Fmt.dayMonth(violation.date))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 6)

            Text(Fmt.r(violation.r))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.red)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private var tradesButton: some View {
        Button {
            showTrades = true
            Haptics.tap()
        } label: {
            Text("Показать сделки")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var mandateInfoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Мандат обновлён \(mandateDateText).")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                Text("Следующая ревизия — через 45 дней.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var mandateDateText: String {
        guard let date = report.mandateDate else { return "—" }
        return Fmt.shortDay(date)
    }

    // MARK: - No mandate

    private var noMandateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            BreathingGlyph(systemName: "doc.badge.plus")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)

            Text("Мандата пока нет")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("Мандат — это лимиты фонда: риск на сделку, на день и на месяц, доля инструмента, группы и фактора. Без него комплаенсу не с чем сверять сделки.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Создать мандат") {
                showMandateEditor = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }
}

// MARK: - All violations sheet

private struct AllViolationsSheet: View {
    let report: ComplianceReport
    var onOpen: (Trade) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var limit: MandateLimit?

    private var items: [ComplianceViolation] {
        report.violations(for: limit)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Нарушения")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Проверка по активной версии мандата.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "Все", isSelected: limit == nil) {
                            limit = nil
                            Haptics.select()
                        }
                        ForEach(MandateLimit.allCases) { item in
                            Chip(
                                title: item.shortTitle,
                                isSelected: limit == item
                            ) {
                                limit = item
                                Haptics.select()
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }

                if items.isEmpty {
                    Text("По этому лимиту нарушений нет.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, violation in
                            Button {
                                if let trade = violation.trade {
                                    onOpen(trade)
                                }
                                Haptics.tap()
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(violation.limit.rawValue)
                                            .font(.system(size: 14.5, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text("\(violation.symbol) · \(Fmt.dayMonth(violation.date)) · \(violation.detail)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textTertiary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 6)
                                    Text(Fmt.r(violation.r))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.red)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 10)

                            if index < items.count - 1 {
                                Divider()
                                    .overlay(Theme.hairline)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .glassCard(cornerRadius: 20)
                }
            }
            .padding(22)
        }
    }
}

// MARK: - Trades sheet

private struct ComplianceTradesSheet: View {
    let trades: [Trade]
    var onOpen: (Trade) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сделки мандата")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Сделки, которые проверил комплаенс.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                if trades.isEmpty {
                    Text("Нарушений нет.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(trades.enumerated()), id: \.element.persistentModelID) { index, trade in
                            Button {
                                onOpen(trade)
                                Haptics.tap()
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trade.symbol)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("\(Fmt.dayMonth(trade.tradingDay)) · \(trade.result == .open ? "открыта" : trade.result.rawValue) · \(Fmt.r(trade.actualR))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    Spacer(minLength: 6)
                                    Text(Fmt.money(trade.riskUSD))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 10)

                            if index < trades.count - 1 {
                                Divider()
                                    .overlay(Theme.hairline)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .glassCard(cornerRadius: 20)
                }
            }
            .padding(22)
        }
    }
}

// MARK: - Mandate editor

private struct MandateEditorSheet: View {
    let version: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var riskPerTrade = "1"
    @State private var riskPerDay = "3"
    @State private var riskPerMonth = "8"
    @State private var maxTrades = "2"
    @State private var maxInstrument = "25"
    @State private var maxGroup = "40"
    @State private var maxFactor = "50"
    @State private var note = ""

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Мандат v\(version)")
                            Text("Лимиты фонда")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer(minLength: 8)
                        Button("Закрыть") {
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }

                    numberField("Риск на сделку, % капитала", text: $riskPerTrade)
                    numberField("Риск дня, % капитала", text: $riskPerDay)
                    numberField("Риск месяца, % капитала", text: $riskPerMonth)
                    numberField("Сделок в день", text: $maxTrades)
                    numberField("Доля инструмента, %", text: $maxInstrument)
                    numberField("Доля группы, %", text: $maxGroup)
                    numberField("Доля фактора, %", text: $maxFactor)

                    GlassNoteField(
                        placeholder: "Почему такие лимиты",
                        text: $note,
                        limit: 300,
                        lines: 2...3,
                        minHeight: 52
                    )

                    PrimaryButton(title: "Активировать мандат") {
                        save()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private func numberField(_ placeholder: String, text: Binding<String>) -> some View {
        GlassNoteField(
            placeholder: placeholder,
            text: text,
            limit: 12,
            lines: 1...1,
            minHeight: 44
        )
    }

    private func value(_ text: String, fallback: Double) -> Double {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? fallback
    }

    private func save() {
        for mandate in (try? context.fetch(FetchDescriptor<FundMandate>())) ?? [] {
            mandate.isActive = false
        }

        let mandate = FundMandate(
            version: version,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: true
        )
        mandate.riskPerTradePercent = max(0.1, value(riskPerTrade, fallback: 1))
        mandate.riskPerDayPercent = max(0.1, value(riskPerDay, fallback: 3))
        mandate.riskPerMonthPercent = max(0.1, value(riskPerMonth, fallback: 8))
        mandate.maxTradesPerDay = max(1, Int(value(maxTrades, fallback: 2)))
        mandate.maxInstrumentPercent = max(1, value(maxInstrument, fallback: 25))
        mandate.maxGroupPercent = max(1, value(maxGroup, fallback: 40))
        mandate.maxFactorPercent = max(1, value(maxFactor, fallback: 50))

        context.insert(mandate)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

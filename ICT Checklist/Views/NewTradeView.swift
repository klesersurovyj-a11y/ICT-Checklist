//
//  NewTradeView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct NewTradeView: View {
    let prefillTrade: Trade?

    init(prefillTrade: Trade? = nil) {
        self.prefillTrade = prefillTrade
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsList: [AppSettings]
    @Query private var ladderList: [RiskLadderState]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var symbol = ""
    @State private var direction: Direction = .long
    @State private var entry: Double?
    @State private var stop: Double?
    @State private var takeProfit: Double?
    @State private var risk: Double = 12
    @State private var stepIndex = 0
    @State private var account: TradingAccount? = nil
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var note = ""
    @State private var didLoad = false

    private var settings: AppSettings? { settingsList.first }

    private var amounts: [Double] {
        let list = settings?.ladderAmounts ?? []
        return list.count == 3 ? list : [12, 25, 50]
    }

    private var symbols: [String] {
        let list = settings?.symbols ?? []
        return list.isEmpty ? ["EURUSD", "GBPUSD", "XAUUSD"] : list
    }

    private var minRR: Double { settings?.minRR ?? 2.0 }

    private var rr: Double? {
        guard let entry, let stop, let takeProfit, entry > 0 else { return nil }
        let riskValue = abs(entry - stop)
        let reward = abs(takeProfit - entry)
        guard riskValue > 0, reward > 0 else { return nil }
        return reward / riskValue
    }

    private var canSave: Bool {
        entry != nil && stop != nil && takeProfit != nil && rr != nil && !symbol.isEmpty
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
                    tradeCard
                        .reveal(.zoom, 1)
                    tagsCard
                        .reveal(.rise, 2)
                    noteField
                        .reveal(.rise, 3)
                    footer
                        .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .onAppear(perform: loadDefaults)
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: prefillTrade == nil ? "Вручную" : "Дубликат сделки")
            ScreenTitle(text: "Новая сделка")
            Text(headerSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        let base = "Сегодня · \(Fmt.shortDay(.now)) · ступень \(stepIndex + 1)"
        guard let prefillTrade else { return base }
        return "\(base) · RR из сделки \(Fmt.rr(prefillTrade.plannedRR))"
    }

    // MARK: - Trade form

    private var tradeCard: some View {
        VStack(spacing: 0) {
            formRow("Символ") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { item in
                            Chip(title: item, isSelected: symbol == item) {
                                symbol = item
                                Haptics.select()
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            divider

            formRow("Направление") {
                GlassSegmented(
                    options: Direction.allCases,
                    selection: $direction,
                    label: { $0.rawValue },
                    tint: { $0 == .long ? Theme.green : Theme.red }
                )
            }

            divider

            formRow("Счёт") {
                accountMenu
            }

            divider

            formRow("Entry") {
                InlineNumberField(value: $entry, placeholder: "1.0000")
            }

            divider

            formRow("SL") {
                InlineNumberField(value: $stop, placeholder: "1.0000")
            }

            divider

            formRow("TP") {
                InlineNumberField(value: $takeProfit, placeholder: "1.0000")
            }

            divider

            formRow("Риск") {
                HStack(spacing: 10) {
                    InlineNumberField(value: Binding(
                        get: { risk },
                        set: { risk = max(0, $0 ?? 0) }
                    ), prefix: "$", placeholder: "0")
                    .frame(maxWidth: 130, alignment: .leading)

                    Text("Ступень")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    stepMenu
                }
            }

            Divider()
                .overlay(Theme.hairline)
                .padding(.vertical, 4)

            rrVerdict

            Text("Минимальный RR — \(Fmt.rr(minRR))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var divider: some View {
        Divider().overlay(Theme.hairline)
    }

    private func formRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 100, alignment: .leading)
            content()
        }
        .padding(.vertical, 7)
    }

    private var accountMenu: some View {
        Menu {
            Button("Без счёта") {
                account = nil
                Haptics.select()
            }
            if !accounts.isEmpty {
                Divider()
                ForEach(accounts) { item in
                    Button("\(item.name) · \(item.type.rawValue)") {
                        account = item
                        Haptics.select()
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(account.map { $0.name } ?? "Без счёта")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(account == nil ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    private var stepMenu: some View {
        Menu {
            ForEach(0..<3, id: \.self) { index in
                Button("Ступень \(index + 1) — \(Fmt.money(amounts[index]))") {
                    stepIndex = index
                    risk = amounts[index]
                    Haptics.select()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(stepIndex + 1)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    // MARK: - RR verdict

    @ViewBuilder
    private var rrVerdict: some View {
        if let rr {
            let allowed = rr >= minRR
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill((allowed ? Theme.green : Theme.red).opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: allowed ? "checkmark" : "exclamationmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(allowed ? Theme.green : Theme.red)
                }
                Text(
                    allowed
                        ? "RR \(Fmt.rr(rr)) — вход разрешён"
                        : "RR \(Fmt.rr(rr)) — ниже минимума \(Fmt.rr(minRR))"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(allowed ? Theme.green : Theme.red)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((allowed ? Theme.green : Theme.red).opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder((allowed ? Theme.green : Theme.red).opacity(0.30), lineWidth: 1)
            )
        } else {
            InfoHint(text: "Заполните Entry, SL и TP — RR посчитается автоматически.")
        }
    }

    // MARK: - Tags

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Метки")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(tags.count)/5")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Button {
                                    tags.removeAll { $0 == tag }
                                    Haptics.tap()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            HStack(spacing: 8) {
                TextField("Новая метка", text: $newTag)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .onSubmit(addTag)
                Button(action: addTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(canAddTag ? Theme.accent : Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canAddTag)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var canAddTag: Bool {
        let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, tags.count < 5 else { return false }
        return !tags.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    private func addTag() {
        let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, tags.count < 5 else { return }
        guard !tags.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            newTag = ""
            return
        }
        tags.append(value)
        newTag = ""
        Haptics.tap()
    }

    // MARK: - Note and footer

    private var noteField: some View {
        GlassNoteField(placeholder: "Заметка к сделке…", text: $note, limit: 300, lines: 2...4, minHeight: 64)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Открыть сделку", isEnabled: canSave) {
                save()
            }
            Text("Сделка появится в журнале и не блокирует цикл дня")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Actions

    private func loadDefaults() {
        guard !didLoad else { return }
        didLoad = true

        if let source = prefillTrade {
            symbol = source.symbol
            direction = source.direction
            stepIndex = min(max(source.ladderStepIndex, 0), 2)
            risk = source.riskUSD
            if accounts.count == 1 {
                account = accounts.first
            }
            return
        }

        stepIndex = min(max(ladderList.first?.stepIndex ?? 0, 0), 2)
        risk = amounts[stepIndex]
        symbol = symbols.first ?? "EURUSD"
        if accounts.count == 1 {
            account = accounts.first
        }
    }

    private func save() {
        guard let entry, let stop, let takeProfit, let rr else {
            Haptics.warning()
            return
        }
        let trade = Trade(
            entryDate: .now,
            tradingDay: Calendar.current.startOfDay(for: .now),
            symbol: symbol,
            direction: direction,
            ladderStepIndex: stepIndex,
            riskUSD: risk,
            entry: entry,
            stop: stop,
            takeProfit: takeProfit,
            plannedRR: rr,
            note: note
        )
        trade.tags = tags
        trade.account = account
        context.insert(trade)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Inline numeric field

private struct InlineNumberField: View {
    @Binding var value: Double?
    var prefix: String? = nil
    var placeholder: String = "0.0000"

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 2) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .onAppear {
            text = value.map { Fmt.price($0) } ?? ""
        }
        .onChange(of: text) { _, newValue in
            let normalized = newValue.replacingOccurrences(of: ",", with: ".")
            let parsed = Double(normalized)
            if parsed != value {
                value = parsed
            }
        }
        .onChange(of: value) { _, newValue in
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            if Double(normalized) != newValue {
                text = newValue.map { Fmt.price($0) } ?? ""
            }
        }
    }
}

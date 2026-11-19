//
//  NewTradeView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct NewTradeView: View {
    let prefillTrade: Trade?
    let prefill: NewTradePrefill?
    let prefillSetup: PlaybookSetup?

    init(prefillTrade: Trade? = nil, prefill: NewTradePrefill? = nil, setup: PlaybookSetup? = nil) {
        self.prefillTrade = prefillTrade
        self.prefill = prefill
        self.prefillSetup = setup
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsList: [AppSettings]
    @Query private var ladderList: [RiskLadderState]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \Trade.entryDate, order: .reverse) private var allTrades: [Trade]
    @Query(sort: \TradingCycle.day, order: .reverse) private var cycles: [TradingCycle]

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
    @State private var structure: MarketStructure? = nil
    @State private var poi: POIType? = nil
    @State private var note = ""
    @State private var checks: Set<TradeCheck> = []
    @State private var memoThesis = ""
    @State private var memoPricedIn = ""
    @State private var memoScenarios = ""
    @State private var memoInvalidation = ""
    @State private var memoAnswers = ""
    @State private var memoRejectReason = ""
    @State private var memoVerdictRaw = MemoVerdict.none.rawValue
    @State private var redTeamReplies: [String: String] = [:]
    @State private var shotItems: [PhotosPickerItem] = []
    @State private var pendingShots: [Data] = []
    @State private var didLoad = false

    private var settings: AppSettings? { settingsList.first }

    private var amounts: [Double] {
        let list = settings?.ladderAmounts ?? []
        return list.count == 3 ? list : [12, 25, 50]
    }

    private var symbols: [String] {
        let configured = settings?.symbols ?? []
        var list = configured.isEmpty ? ["EURUSD", "GBPUSD", "XAUUSD"] : configured
        if let prefillSetup {
            for symbol in prefillSetup.symbols where !list.contains(symbol) {
                list.append(symbol)
            }
        }
        return list
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

    private var objections: [RedTeamObjection] {
        InvestmentCommittee.objections(
            thesis: memoThesis,
            invalidation: memoInvalidation,
            checkedCount: checks.count,
            totalChecks: TradeCheck.allCases.count,
            rr: rr ?? 0,
            minRR: minRR
        )
    }

    private var draftSetupName: String {
        if let prefillSetup, !prefillSetup.title.isEmpty {
            return prefillSetup.title
        }
        if let prefillTrade {
            return RedTeamHistory.setupTitle(of: prefillTrade)
        }
        return ""
    }

    private var historyObjections: [RedTeamHistoryObjection] {
        RedTeamHistory.objections(
            for: RedTeamHistory.draft(
                symbol: symbol,
                direction: direction,
                setupName: draftSetupName
            ),
            trades: allTrades
        )
    }

    private var historyAnswered: Bool {
        RedTeamHistory.isAnswered(historyObjections, replies: redTeamReplies)
    }

    private var snapshotCycle: TradingCycle? {
        prefillTrade?.cycle ?? cycles.first { Calendar.current.isDateInToday($0.day) }
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
                    classificationCard
                        .reveal(.rise, 2)
                    tagsCard
                        .reveal(.rise, 3)
                    TradeChecklistCard(checks: checks) { item in
                        if checks.contains(item) {
                            checks.remove(item)
                        } else {
                            checks.insert(item)
                        }
                        Haptics.select()
                    }
                    .reveal(.rise, 4)

                    InvestmentMemoCard(
                        thesis: $memoThesis,
                        pricedIn: $memoPricedIn,
                        scenarios: $memoScenarios,
                        invalidation: $memoInvalidation,
                        answers: $memoAnswers,
                        rejectReason: $memoRejectReason,
                        verdictRaw: $memoVerdictRaw,
                        objections: objections,
                        historyObjections: historyObjections,
                        replies: $redTeamReplies
                    )
                    .reveal(.rise, 5)

                    noteField
                        .reveal(.rise, 6)
                    shotsCard
                        .reveal(.rise, 7)
                    footer
                        .reveal(.rise, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .onAppear(perform: loadDefaults)
        .onChange(of: shotItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadShots(items) }
        }
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
                .glassCircle()
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: sourceLabel)
            ScreenTitle(text: "Новая сделка")
            Text(headerSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceLabel: String {
        if prefillTrade != nil { return "Дубликат сделки" }
        if prefillSetup != nil { return "Сделка по сетапу" }
        if prefill != nil { return "Из калькулятора" }
        return "Вручную"
    }

    private var headerSubtitle: String {
        let base = "Сегодня · \(Fmt.shortDay(.now)) · ступень \(stepIndex + 1)"
        if let prefillSetup {
            return "\(base) · \(prefillSetup.title) · RR \(String(format: "%.1f", prefillSetup.typicalRR))"
        }
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

    // MARK: - Classification

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Поведение рынка")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("необязательно")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Структура")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MarketStructure.allCases) { value in
                            Chip(title: value.rawValue, isSelected: structure == value) {
                                structure = structure == value ? nil : value
                                Haptics.select()
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "POI")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(POIType.allCases) { value in
                            Chip(title: value.rawValue, isSelected: poi == value) {
                                poi = poi == value ? nil : value
                                Haptics.select()
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            Text("Если не выбирать, структура и POI возьмутся из цикла дня — у ручной сделки их можно поставить позже в её карточке.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
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

    // MARK: - Screenshots at entry

    private var shotsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Скриншоты до входа")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(pendingShots.count)/3")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(pendingShots.enumerated()), id: \.offset) { index, data in
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Color.white.opacity(0.04)
                                        Image(systemName: "photo")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                }
                            }
                            .frame(width: 74, height: 74)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                pendingShots.remove(at: index)
                                Haptics.tap()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }

                    PhotosPicker(
                        selection: $shotItems,
                        maxSelectionCount: 3,
                        matching: .images
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.14),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 74, height: 74)
                    }
                    .disabled(pendingShots.count >= 3)
                    .opacity(pendingShots.count >= 3 ? 0.4 : 1)
                }
                .padding(.vertical, 2)
            }

            Text("Снимок входа сохранит их вместе с уровнями цикла, ступенью, банками и лимитами дня.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Открыть сделку", isEnabled: canSave) {
                save()
            }
            Text(
                checks.count == TradeCheck.allCases.count
                    ? "Сделка пройдёт по системе — чек-лист закрыт"
                    : "Не все пункты отмечены: сделка сохранится как «вне системы»"
            )
            .font(.system(size: 12))
            .foregroundStyle(checks.count == TradeCheck.allCases.count ? Theme.green : Theme.textTertiary)
            .multilineTextAlignment(.center)

            Text(memoCaption)
                .font(.system(size: 12))
                .foregroundStyle(memoCaptionTint)
                .multilineTextAlignment(.center)
        }
    }

    private var memoCaption: String {
        if !historyAnswered {
            return "Красная команда: возражений по истории без ответа \(historyObjections.count)"
        }
        switch MemoVerdict(rawValue: memoVerdictRaw) ?? .none {
        case .approved:
            return "Комитет утвердил вход: тезис и инвалидация записаны"
        case .rejected:
            return "Комитет отклонил идею — сделка сохранится как вне системы"
        case .none:
            if objections.isEmpty {
                return "Возражений нет — осталось утвердить меморандум"
            }
            return "Без ответов на возражения комитет вход не утверждает"
        }
    }

    private var memoCaptionTint: Color {
        switch MemoVerdict(rawValue: memoVerdictRaw) ?? .none {
        case .approved: return Theme.green
        case .rejected: return Theme.red
        case .none: return Theme.textTertiary
        }
    }

    // MARK: - Actions

    private func loadDefaults() {
        guard !didLoad else { return }
        didLoad = true

        stepIndex = min(max(ladderList.first?.stepIndex ?? 0, 0), 2)
        risk = amounts[stepIndex]
        symbol = symbols.first ?? "EURUSD"
        if accounts.count == 1 {
            account = accounts.first
        }

        if let source = prefillTrade {
            symbol = source.symbol
            direction = source.direction
            stepIndex = min(max(source.ladderStepIndex, 0), 2)
            risk = source.riskUSD
            structure = source.explicitStructure
            poi = source.explicitPOI
            return
        }

        if let prefillSetup {
            if let first = prefillSetup.symbols.first {
                symbol = first
            }
            if let direction = prefillSetup.direction.tradeDirection {
                self.direction = direction
            }
            return
        }

        if let prefill {
            entry = prefill.entry
            stop = prefill.stop
            takeProfit = prefill.takeProfit
            risk = prefill.riskUSD
            direction = prefill.stop <= prefill.entry ? .long : .short
            if let value = prefill.symbol, !value.isEmpty {
                symbol = value
            }
        }
    }

    private func loadShots(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }
        pendingShots = Array((pendingShots + loaded).prefix(3))
        shotItems = []
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
        trade.structureRaw = structure?.rawValue ?? ""
        trade.poiRaw = poi?.rawValue ?? ""
        trade.account = account
        trade.setup = prefillSetup
        trade.setupName = prefillSetup?.title ?? ""
        trade.checklistRaw = checks.map(\.rawValue).sorted().joined(separator: ",")
        trade.memoThesis = memoThesis.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoPricedIn = memoPricedIn.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoScenarios = memoScenarios.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoInvalidation = memoInvalidation.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoAnswers = memoAnswers.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoRejectReason = memoRejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.memoVerdictRaw = memoVerdictRaw
        trade.redTeamHistory = historyObjections
        trade.redTeamReplies = RedTeamHistory.cleaned(redTeamReplies)
        context.insert(trade)

        for data in pendingShots {
            let shot = TradeShot(imageData: data, createdAt: trade.entryDate, role: .beforeEntry)
            context.insert(shot)
            trade.shots.append(shot)
        }

        trade.snapshot = TradeSnapshotBuilder.make(
            .init(
                symbol: symbol,
                direction: direction,
                entry: entry,
                stop: stop,
                takeProfit: takeProfit,
                riskUSD: risk,
                plannedRR: rr,
                setupName: prefillSetup?.title ?? "",
                ladderStep: stepIndex,
                ladderAmounts: amounts,
                accumulatedR: ladderList.first?.accumulatedR ?? 0,
                cycle: snapshotCycle,
                settings: settings,
                ladderState: ladderList.first,
                trades: allTrades + [trade],
                thesis: memoThesis.trimmingCharacters(in: .whitespacesAndNewlines),
                pricedIn: memoPricedIn.trimmingCharacters(in: .whitespacesAndNewlines),
                scenarios: memoScenarios.trimmingCharacters(in: .whitespacesAndNewlines),
                invalidation: memoInvalidation.trimmingCharacters(in: .whitespacesAndNewlines),
                answers: memoAnswers.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: tags,
                checks: checks,
                shotCount: pendingShots.count
            )
        )

        try? context.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Prefill from the position calculator

struct NewTradePrefill: Identifiable {
    let id = UUID()
    var entry: Double
    var stop: Double
    var takeProfit: Double
    var riskUSD: Double
    var symbol: String?
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

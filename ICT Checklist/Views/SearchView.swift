//
//  SearchView.swift
//  ICT Checklist
//
//  Глобальный поиск по базе: сделки, планы, Second Brain,
//  ошибки и дневник — с недавними запросами и группировкой по разделам.
//

import SwiftUI
import SwiftData

// MARK: - Categories

private enum SearchCategory: String, CaseIterable, Identifiable {
    case trades = "Сделки"
    case notes = "Second Brain"
    case plans = "Планы"
    case errors = "Ошибки"
    case journal = "Дневник"
    case assistant = "Ассистент"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .trades: return "chart.xyaxis.line"
        case .notes: return "brain.head.profile"
        case .plans: return "calendar"
        case .errors: return "exclamationmark.triangle"
        case .journal: return "book.closed"
        case .assistant: return "bubble.left.and.bubble.right"
        }
    }

    var hint: String {
        switch self {
        case .trades: return "Символ, заметка, теги, разбор"
        case .notes: return "Наблюдения, гипотезы, правила"
        case .plans: return "Тезис, сценарии A и B, выводы"
        case .errors: return "Что нарушило систему"
        case .journal: return "Состояние и выводы дня"
        case .assistant: return "Вопросы и ответы чата"
        }
    }
}

private struct AssistantPair: Identifiable {
    let user: AssistantMessage
    let question: String
    let answer: String

    var id: String { String(describing: user.id) }
    var date: Date { user.createdAt }
}

private enum SearchSelection: Identifiable {
    case trade(Trade)
    case note(BrainNote)
    case plan(TradePlan)
    case journal
    case assistant(AssistantMessage)

    var id: String {
        switch self {
        case .trade(let trade): return "trade-\(String(describing: trade.id))"
        case .note(let note): return "note-\(String(describing: note.id))"
        case .plan(let plan): return "plan-\(String(describing: plan.id))"
        case .journal: return "journal"
        case .assistant(let message): return "assistant-\(String(describing: message.id))"
        }
    }
}

// MARK: - Screen

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \TradePlan.day, order: .reverse) private var plans: [TradePlan]
    @Query(sort: \BrainNote.updatedAt, order: .reverse) private var notes: [BrainNote]
    @Query(sort: \ErrorNote.updatedAt, order: .reverse) private var errors: [ErrorNote]
    @Query(sort: \JournalEntry.day, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \AssistantMessage.createdAt) private var assistantMessages: [AssistantMessage]

    @AppStorage("search.recentQueries") private var recentsRaw: String = ""

    @State private var query = ""
    @State private var selection: SearchSelection?
    @State private var selectedError: ErrorNote?
    @State private var expanded: Set<SearchCategory> = []

    @FocusState private var fieldFocused: Bool

    private let rowLimit = 4

    // MARK: - Matching

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmed.isEmpty }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    private func matches(_ fields: [String]) -> Bool {
        fields.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    private var matchedTrades: [Trade] {
        guard isSearching else { return [] }
        return trades.filter { trade in
            var fields: [String] = [trade.symbol, trade.note, trade.tags.joined(separator: " ")]
            if let review = trade.review {
                fields.append(review.entryReason)
                fields.append(review.marketContext)
                fields.append(review.resultReason)
            }
            if let plan = trade.plan {
                fields.append(plan.title)
                fields.append(plan.symbol)
            }
            return matches(fields)
        }
    }

    private var matchedNotes: [BrainNote] {
        guard isSearching else { return [] }
        return notes.filter { note in
            matches([
                note.title,
                note.topic,
                note.summary,
                note.keyPoints.joined(separator: " "),
                note.benefits,
                note.conclusions,
                note.kind.short
            ])
        }
    }

    private var matchedPlans: [TradePlan] {
        guard isSearching else { return [] }
        return plans.filter { plan in
            matches([
                plan.title,
                plan.symbol,
                plan.thesis,
                plan.planA,
                plan.planB,
                plan.adaptation,
                plan.note,
                plan.conclusions,
                plan.narrative
            ])
        }
    }

    private var matchedErrors: [ErrorNote] {
        guard isSearching else { return [] }
        return errors.filter { note in
            matches([note.title, note.text, note.status.rawValue])
        }
    }

    private var matchedJournal: [JournalEntry] {
        guard isSearching else { return [] }
        return journal.filter { entry in
            matches([entry.note, entry.improve, entry.mood.rawValue])
        }
    }

    private var matchedAssistant: [AssistantPair] {
        guard isSearching else { return [] }
        return assistantPairs.filter { pair in
            matches([pair.question, pair.answer])
        }
    }

    private var assistantPairs: [AssistantPair] {
        let list = assistantMessages
        var pairs: [AssistantPair] = []
        var index = 0

        while index < list.count {
            let message = list[index]

            guard message.isUser else {
                index += 1
                continue
            }

            var answer = ""
            if index + 1 < list.count, !list[index + 1].isUser {
                answer = list[index + 1].text
                index += 2
            } else {
                index += 1
            }

            pairs.append(
                AssistantPair(
                    user: message,
                    question: message.text,
                    answer: answer
                )
            )
        }

        return Array(pairs.reversed())
    }

    private var totalMatches: Int {
        matchedTrades.count
            + matchedNotes.count
            + matchedPlans.count
            + matchedErrors.count
            + matchedJournal.count
            + matchedAssistant.count
    }

    // MARK: - Recents

    private var recentQueries: [String] {
        guard
            let data = recentsRaw.data(using: .utf8),
            let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return list
    }

    private func remember(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }

        var list = recentQueries.filter { $0.caseInsensitiveCompare(value) != .orderedSame }
        list.insert(value, at: 0)

        guard
            let data = try? JSONEncoder().encode(Array(list.prefix(8))),
            let encoded = String(data: data, encoding: .utf8)
        else { return }
        recentsRaw = encoded
    }

    private func clearRecents() {
        recentsRaw = ""
        Haptics.tap()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .reveal(.drop)
                    searchField
                        .reveal(.blur, 1)

                    if isSearching {
                        if totalMatches == 0 {
                            noResults
                                .reveal(.rise, 2)
                        } else {
                            summaryLine
                                .reveal(.rise, 2)
                            results
                        }
                    } else {
                        if !recentQueries.isEmpty {
                            recentsCard
                                .reveal(.rise, 2)
                        }
                        scopeCard
                            .reveal(.rise, 3)
                    }

                    Text("Поиск идёт по всей базе, включая разборы сделок и заметки Second Brain.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(item: $selection) { target in
            switch target {
            case .trade(let trade):
                TradeDetailView(trade: trade, usedTags: usedTags)
            case .note(let note):
                BrainNoteView(note: note)
            case .plan(let plan):
                PlanView(plan: plan)
            case .journal:
                JournalView()
            case .assistant(let message):
                AssistantView(focusMessage: message)
            }
        }
        .sheet(item: $selectedError) { note in
            SearchErrorDetail(note: note)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .onChange(of: query) { _, _ in
            expanded = []
        }
        .task {
            guard !isSearching else { return }
            try? await Task.sleep(nanoseconds: 320_000_000)
            fieldFocused = true
        }
    }

    // MARK: - Header and field

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "База знаний")
                ScreenTitle(text: "Поиск")
                Text("Сделки, планы, Second Brain, ошибки и дневник — в одном месте.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Символ, сделка, наблюдение, ошибка…", text: $query)
                .focused($fieldFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .tint(Theme.accent)
                .onSubmit { remember(trimmed) }

            if !query.isEmpty {
                Button {
                    query = ""
                    fieldFocused = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Empty state

    private var recentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Недавние запросы")
                Spacer(minLength: 8)
                Button {
                    clearRecents()
                } label: {
                    Text("Очистить")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentQueries, id: \.self) { text in
                        Button {
                            query = text
                            fieldFocused = true
                            Haptics.select()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(text)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .glassCapsule()
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Что ищется")
                .padding(.bottom, 4)

            scopeRow(.trades, count: trades.count)
            Divider().overlay(Theme.hairline)
            scopeRow(.notes, count: notes.count)
            Divider().overlay(Theme.hairline)
            scopeRow(.plans, count: plans.count)
            Divider().overlay(Theme.hairline)
            scopeRow(.errors, count: errors.count)
            Divider().overlay(Theme.hairline)
            scopeRow(.journal, count: journal.count)
            Divider().overlay(Theme.hairline)
            scopeRow(.assistant, count: assistantPairs.count)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func scopeRow(_ category: SearchCategory, count: Int) -> some View {
        HStack(spacing: 10) {
            iconCircle(systemName: category.icon, tint: Theme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(category.hint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 7)
    }

    private var noResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("По запросу «\(trimmed)» пусто. Попробуйте символ (EURUSD), слово из заметки или название правила из Second Brain.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Results

    private var summaryLine: some View {
        Text("НАЙДЕНО: \(totalMatches)")
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private var results: some View {
        if !matchedTrades.isEmpty {
            section(.trades, count: matchedTrades.count) {
                let rows = visible(matchedTrades, .trades)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, trade in
                    Button {
                        open(.trade(trade))
                    } label: {
                        tradeRow(trade)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }

        if !matchedNotes.isEmpty {
            section(.notes, count: matchedNotes.count) {
                let rows = visible(matchedNotes, .notes)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, note in
                    Button {
                        open(.note(note))
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }

        if !matchedPlans.isEmpty {
            section(.plans, count: matchedPlans.count) {
                let rows = visible(matchedPlans, .plans)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, plan in
                    Button {
                        open(.plan(plan))
                    } label: {
                        planRow(plan)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }

        if !matchedErrors.isEmpty {
            section(.errors, count: matchedErrors.count) {
                let rows = visible(matchedErrors, .errors)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, note in
                    Button {
                        remember(trimmed)
                        selectedError = note
                        Haptics.tap()
                    } label: {
                        errorRow(note)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }

        if !matchedJournal.isEmpty {
            section(.journal, count: matchedJournal.count) {
                let rows = visible(matchedJournal, .journal)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        open(.journal)
                    } label: {
                        journalRow(entry)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }

        if !matchedAssistant.isEmpty {
            section(.assistant, count: matchedAssistant.count) {
                let rows = visible(matchedAssistant, .assistant)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, pair in
                    Button {
                        remember(trimmed)
                        selection = .assistant(pair.user)
                        Haptics.tap()
                    } label: {
                        assistantRow(pair)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ category: SearchCategory,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(category, count: count)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .glassCard(cornerRadius: 20)
        }
    }

    private func sectionHeader(_ category: SearchCategory, count: Int) -> some View {
        HStack(spacing: 8) {
            SectionLabel(text: "\(category.rawValue) · \(count)")

            Spacer(minLength: 6)

            if count > rowLimit {
                Button {
                    toggle(category)
                } label: {
                    HStack(spacing: 3) {
                        Text(expanded.contains(category) ? "Свернуть" : "Все")
                        Image(systemName: isExpandedIcon(category))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isExpandedIcon(_ category: SearchCategory) -> String {
        expanded.contains(category) ? "chevron.up" : "chevron.right"
    }

    private func toggle(_ category: SearchCategory) {
        withAnimation(Theme.snappy) {
            if expanded.contains(category) {
                expanded.remove(category)
            } else {
                expanded.insert(category)
            }
        }
        Haptics.tap()
    }

    private func visible<T>(_ items: [T], _ category: SearchCategory) -> [T] {
        expanded.contains(category) ? items : Array(items.prefix(rowLimit))
    }

    private func open(_ target: SearchSelection) {
        remember(trimmed)
        selection = target
        Haptics.tap()
    }

    // MARK: - Rows

    private func tradeRow(_ trade: Trade) -> some View {
        let tint = trade.direction == .long ? Theme.green : Theme.red

        return HStack(spacing: 10) {
            iconCircle(
                systemName: trade.direction == .long ? "arrow.up.right" : "arrow.down.right",
                tint: tint
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(trade.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(Fmt.shortDay(trade.tradingDay)) · \(Fmt.time(trade.entryDate))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            pill(trade.direction.rawValue, tint: tint)

            Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(trade.result == .open ? Theme.textSecondary : rColor(trade.actualR))
                .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func noteRow(_ note: BrainNote) -> some View {
        HStack(spacing: 10) {
            iconCircle(systemName: note.kind.icon, tint: note.kind.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.displayTitle)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(note.kind.short) · \(Fmt.shortDay(note.updatedAt))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if note.kind.usesStatus {
                pill(note.status.rawValue, tint: note.status.tint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func planRow(_ plan: TradePlan) -> some View {
        let title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let tint = plan.direction == .long ? Theme.green : Theme.red

        return HStack(spacing: 10) {
            iconCircle(systemName: "calendar", tint: Theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? plan.symbol : title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(Fmt.shortDay(plan.day)) · \(plan.result.rawValue)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            pill(plan.direction.rawValue, tint: tint)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func errorRow(_ note: ErrorNote) -> some View {
        let tint = errorTint(note.status)

        return HStack(spacing: 10) {
            iconCircle(systemName: "exclamationmark.triangle", tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(Fmt.shortDay(note.updatedAt)) · \(Fmt.deals(note.trades.count))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            pill(note.status.rawValue, tint: tint)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func journalRow(_ entry: JournalEntry) -> some View {
        HStack(spacing: 10) {
            iconCircle(systemName: "book.closed", tint: Theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.day(entry.day))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.preview.isEmpty ? entry.mood.rawValue : entry.preview)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            pill(entry.mood.rawValue, tint: Theme.textSecondary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func assistantRow(_ pair: AssistantPair) -> some View {
        HStack(spacing: 10) {
            iconCircle(systemName: "bubble.left.and.bubble.right", tint: Theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(firstLine(pair.question, fallback: "Вопрос"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(firstLine(pair.answer, fallback: "Без ответа"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            Text(Fmt.shortDay(pair.date))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func firstLine(_ text: String, fallback: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return line.isEmpty ? fallback : line
    }

    // MARK: - Pieces

    private func iconCircle(systemName: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 34, height: 34)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private func errorTint(_ status: ErrorStatus) -> Color {
        switch status {
        case .awaiting: return Theme.orange
        case .fixed: return Theme.green
        case .repeated: return Theme.red
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Error detail

private struct SearchErrorDetail: View {
    let note: ErrorNote

    @Environment(\.dismiss) private var dismiss

    private var tint: Color {
        switch note.status {
        case .awaiting: return Theme.orange
        case .fixed: return Theme.green
        case .repeated: return Theme.red
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Ошибка · \(Fmt.shortDay(note.createdAt))")
                            Text(note.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 4)

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 34, height: 34)
                                .glassCircle()
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Text(note.status.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(tint.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1))

                        Text("\(Fmt.deals(note.trades.count)) · \(Fmt.r(note.totalR))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    if !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note.text)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassCard(cornerRadius: 18)
                    }

                    if !note.sortedTrades.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Сделки")

                            ForEach(note.sortedTrades) { trade in
                                HStack(spacing: 8) {
                                    Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.symbol) · \(trade.result.rawValue)")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 8)
                                    Text(Fmt.r(trade.actualR))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard(cornerRadius: 18)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

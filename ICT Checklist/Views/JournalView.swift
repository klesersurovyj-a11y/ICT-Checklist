//
//  JournalView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \JournalEntry.day, order: .reverse) private var entries: [JournalEntry]

    @State private var todayMood: JournalMood = .calm
    @State private var todayNote = ""
    @State private var todayImprove = ""
    @State private var didLoadToday = false
    @State private var editingEntry: JournalEntry?
    @State private var searchText = ""

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var todayEntry: JournalEntry? {
        entries.first { Calendar.current.isDateInToday($0.day) }
    }

    private var pastEntries: [JournalEntry] {
        entries.filter { !Calendar.current.isDateInToday($0.day) }
    }

    private var filteredPastEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return pastEntries }

        return pastEntries.filter { entry in
            entry.note.localizedCaseInsensitiveContains(query)
                || entry.improve.localizedCaseInsensitiveContains(query)
        }
    }

    private var monthEntries: [JournalEntry] {
        entries
            .filter { Calendar.current.isDate($0.day, equalTo: .now, toGranularity: .month) }
            .sorted { $0.day < $1.day }
    }

    private var monthTitle: String {
        "\(Fmt.month(.now)) \(Calendar.current.component(.year, from: .now))"
    }

    private var caption: String {
        "\(entries.count) \(entriesWord) · \(Fmt.month(.now).lowercased())"
    }

    private var entriesWord: String {
        let mod100 = abs(entries.count) % 100
        let mod10 = abs(entries.count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "записей" }
        if mod10 == 1 { return "запись" }
        if mod10 >= 2 && mod10 <= 4 { return "записи" }
        return "записей"
    }

    var body: some View {
        ZStack {
            AppBackground()

            List {
                headerRow

                todayCardRow

                pastHeaderRow

                if !pastEntries.isEmpty {
                    searchRow
                }

                if pastEntries.isEmpty {
                    emptyRow
                } else if filteredPastEntries.isEmpty {
                    searchEmptyRow
                } else {
                    ForEach(Array(filteredPastEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        pastRow(entry)
                            .reveal(.rise, index)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }

                footerRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
        }
        .sheet(item: $editingEntry) { entry in
            JournalEntrySheet(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .onAppear(perform: loadToday)
        .onDisappear { saveToday() }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    saveToday()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)

                SectionLabel(text: "Дневник")

                Spacer(minLength: 0)

                Button {
                    exportPDF()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11, weight: .semibold))
                        Text("PDF")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(monthEntries.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .disabled(monthEntries.isEmpty)
            }

            ScreenTitle(text: "Дневник трейдера")
                .reveal(.drop, 1)

            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .reveal(.blur, 2)

            if monthEntries.isEmpty {
                Text("За этот месяц записей ещё нет — PDF появится, когда будет первая.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Today

    private var todayCardRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(todayTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(JournalMood.allCases) { mood in
                        Chip(
                            title: mood.rawValue,
                            isSelected: todayMood == mood,
                            tint: mood.tint
                        ) {
                            todayMood = mood
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            GlassNoteField(
                placeholder: "Что видел, что сделал, как держал позицию",
                text: $todayNote,
                limit: 500,
                lines: 3...6,
                minHeight: 96
            )

            TextField("Что улучшить в следующий раз", text: $todayImprove, axis: .vertical)
                .lineLimit(1...2)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )

            PrimaryButton(title: "Сохранить запись") {
                saveToday(force: true)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
        .reveal(.zoom, 3)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var todayTitle: String {
        "Сегодня, \(dayTitle(today))"
    }

    // MARK: - Past days

    private var pastHeaderRow: some View {
        SectionLabel(text: "Прошлые дни")
            .padding(.top, 8)
            .padding(.bottom, 2)
            .reveal(.blur, 4)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Поиск по заметкам", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .tint(Theme.accent)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var searchEmptyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ничего не найдено")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Попробуйте другой запрос — записи не менялись.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                searchText = ""
                Haptics.tap()
            } label: {
                Text("Сбросить запрос")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 18)
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func pastRow(_ entry: JournalEntry) -> some View {
        Button {
            editingEntry = entry
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(entry.day))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(entry.preview.isEmpty ? "Без заметки" : entry.preview)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.preview.isEmpty ? Theme.textTertiary : Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(entry.mood.tint)
                    .frame(width: 12, height: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            BreathingGlyph(systemName: "book.closed")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            Text("Прошлых записей пока нет")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Записи прошлых дней появятся здесь — с настроением дня и первой строкой заметки.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 18)
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var footerRow: some View {
        Text("Записи хранятся в приложении и попадают в резервную копию.")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    // MARK: - Storage

    private func dayTitle(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private func loadToday() {
        guard !didLoadToday else { return }
        didLoadToday = true

        guard let entry = todayEntry else { return }
        todayMood = entry.mood
        todayNote = entry.note
        todayImprove = entry.improve
    }

    private func saveToday(force: Bool = false) {
        guard didLoadToday else { return }

        let note = todayNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let improve = todayImprove.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || !note.isEmpty || !improve.isEmpty else { return }

        if let entry = todayEntry {
            guard entry.mood != todayMood
                || entry.note != note
                || entry.improve != improve
                || force else { return }
            entry.mood = todayMood
            entry.note = note
            entry.improve = improve
            entry.updatedAt = .now
        } else {
            let entry = JournalEntry(day: today, mood: todayMood, note: note, improve: improve)
            context.insert(entry)
        }

        try? context.save()
        JournalReminder.refresh(context: context)
        if force {
            Haptics.success()
        }
    }

    private func delete(_ entry: JournalEntry) {
        context.delete(entry)
        try? context.save()
        Haptics.warning()
    }

    private func exportPDF() {
        saveToday()

        let rows = monthEntries
        guard !rows.isEmpty else {
            Haptics.warning()
            return
        }

        let data = JournalPDFData(
            monthTitle: monthTitle,
            rows: rows.map { entry in
                JournalPDFData.Row(
                    dayTitle: Fmt.day(entry.day),
                    mood: entry.mood.rawValue,
                    note: entry.note.trimmingCharacters(in: .whitespacesAndNewlines),
                    improve: entry.improve.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        )

        guard let url = JournalPDF.make(data) else {
            Haptics.warning()
            SharePresenter.presentFailure()
            return
        }

        SharePresenter.share([url])
        Haptics.success()
    }
}

// MARK: - Mood tint

extension JournalMood {
    var tint: Color {
        switch self {
        case .calm: return Theme.green
        case .confident: return Theme.accent
        case .doubtful: return Color(hex: 0xFFB65C)
        case .rushed: return Theme.red
        }
    }
}

// MARK: - Entry editor

private struct JournalEntrySheet: View {
    @Bindable var entry: JournalEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Дневник")
                            Text(entry.day, format: .dateTime.day().month(.wide))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer(minLength: 8)
                        Button("Готово") {
                            entry.updatedAt = .now
                            try? context.save()
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .reveal(.slideLeft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(JournalMood.allCases) { mood in
                                Chip(
                                    title: mood.rawValue,
                                    isSelected: entry.mood == mood,
                                    tint: mood.tint
                                ) {
                                    entry.mood = mood
                                    entry.updatedAt = .now
                                    try? context.save()
                                    Haptics.select()
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .reveal(.blur, 1)

                    GlassNoteField(
                        placeholder: "Что видел, что сделал, как держал позицию",
                        text: $entry.note,
                        limit: 500,
                        lines: 4...10,
                        minHeight: 130
                    )
                    .reveal(.rise, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ЧТО УЛУЧШИТЬ")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        GlassNoteField(
                            placeholder: "Один короткий вывод на следующий раз",
                            text: $entry.improve,
                            limit: 300,
                            lines: 2...4,
                            minHeight: 60
                        )
                    }
                    .reveal(.rise, 3)

                    PrimaryButton(title: "Сохранить запись") {
                        entry.updatedAt = .now
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                    .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

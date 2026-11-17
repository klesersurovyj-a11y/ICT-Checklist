//
//  SecondBrainView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct SecondBrainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BrainNote.updatedAt, order: .reverse) private var notes: [BrainNote]

    @State private var kindFilter: BrainKind? = nil
    @State private var searchText = ""
    @State private var activeNote: BrainNote?
    @State private var shareItems: [URL] = []
    @State private var showShare = false

    private var filteredNotes: [BrainNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            if let kindFilter, note.kind != kindFilter {
                return false
            }
            if !query.isEmpty {
                let haystack = [
                    note.title,
                    note.topic,
                    note.summary,
                    note.keyRaw,
                    note.benefits,
                    note.conclusions
                ].joined(separator: " ")
                if !haystack.localizedCaseInsensitiveContains(query) {
                    return false
                }
            }
            return true
        }
    }

    private func count(_ kind: BrainKind) -> Int {
        notes.filter { $0.kind == kind }.count
    }

    private var linkedTrades: Int {
        Set(notes.flatMap { $0.trades.map { $0.persistentModelID } }).count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.blur)
                    if filteredNotes.isEmpty {
                        exportHint
                            .reveal(.blur, 1)
                    }
                    tiles
                        .reveal(.zoom, 1)
                    quickMenu
                        .reveal(.rise, 2)

                    if !notes.isEmpty {
                        filterRow
                            .reveal(.slideLeft, 3)
                        searchRow
                            .reveal(.slideLeft, 4)
                    }

                    if filteredNotes.isEmpty {
                        emptyCard
                            .reveal(.rise, 5)
                    } else {
                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                            card(note)
                                .reveal(.slideLeft, index + 5)
                        }
                    }

                    Text("Заметки и формулы хранятся в приложении и попадают в резервную копию.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(item: $activeNote) { note in
            BrainNoteView(note: note)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "База знаний")
                ScreenTitle(text: "Second Brain")
            }

            Spacer(minLength: 8)

            pdfButton

            Button {
                create(.keyNote)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.4), radius: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var pdfButton: some View {
        Button {
            exportPDF()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("PDF")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(filteredNotes.isEmpty ? Theme.textTertiary : Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(filteredNotes.isEmpty)
    }

    private var exportHint: some View {
        Text("Нет записей для экспорта")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func exportPDF() {
        let rows = filteredNotes
        guard !rows.isEmpty else {
            Haptics.warning()
            return
        }

        let data = BrainPDFData(
            dateTitle: Fmt.day(.now),
            rows: rows.map { note in
                BrainPDFData.Row(
                    kind: note.kind.short,
                    title: note.displayTitle,
                    topic: note.topic.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: note.summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    keyTitle: note.kind.keyTitle,
                    keyPoints: note.keyPoints,
                    benefits: note.benefits.trimmingCharacters(in: .whitespacesAndNewlines),
                    conclusions: note.conclusions.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        )

        guard let url = BrainPDF.make(data) else {
            Haptics.warning()
            return
        }

        shareItems = [url]
        showShare = true
        Haptics.success()
    }

    // MARK: - Summary

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("Заметок", "\(count(.keyNote))", tint: Theme.lavender)
            tile("Формул", "\(count(.formula))", tint: Theme.teal)
            tile("Связано", "\(linkedTrades)", tint: Theme.textPrimary)
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Quick menu

    private var quickMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Быстрые действия")
                .padding(.bottom, 4)

            quickRow(
                icon: "bookmark.fill",
                title: "Добавить ключевую заметку",
                subtitle: "Идея, ключ, преимущества и выводы",
                tint: Theme.lavender,
                kind: .keyNote
            )

            Divider()
                .overlay(Theme.hairline)

            quickRow(
                icon: "arrow.triangle.branch",
                title: "Добавить формулу",
                subtitle: "Алгоритм работы по шагам",
                tint: Theme.teal,
                kind: .formula
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func quickRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        kind: BrainKind
    ) -> some View {
        Button {
            create(kind)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint.opacity(0.14)))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func create(_ kind: BrainKind) {
        let note = BrainNote(kind: kind)
        context.insert(note)
        try? context.save()
        activeNote = note
        Haptics.success()
    }

    // MARK: - Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Все \(notes.count)", isSelected: kindFilter == nil) {
                    kindFilter = nil
                    Haptics.select()
                }
                ForEach(BrainKind.allCases) { kind in
                    Chip(
                        title: "\(kind.short) \(count(kind))",
                        isSelected: kindFilter == kind,
                        tint: tint(kind)
                    ) {
                        kindFilter = kindFilter == kind ? nil : kind
                        Haptics.select()
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Поиск по заметкам и формулам", text: $searchText)
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
    }

    // MARK: - Cards

    private func card(_ note: BrainNote) -> some View {
        Button {
            activeNote = note
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: note.kind.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(note.kind.short)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(tint(note.kind))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint(note.kind).opacity(0.14)))
                    .overlay(Capsule().strokeBorder(tint(note.kind).opacity(0.32), lineWidth: 1))

                    if !note.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note.topic)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(Fmt.shortDay(note.updatedAt))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }

                Text(note.displayTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !note.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(note.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if let firstKey = note.keyPoints.first {
                    Text("• \(firstKey)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                let pills = pillTitles(note)
                if !pills.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(pills, id: \.self) { title in
                            Text(title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.07)))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(cornerRadius: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pillTitles(_ note: BrainNote) -> [String] {
        var pills: [String] = []
        if !note.keyPoints.isEmpty { pills.append("Пунктов \(note.keyPoints.count)") }
        if !note.photos.isEmpty { pills.append("Фото \(note.photos.count)") }
        if !note.trades.isEmpty { pills.append("Сделок \(note.trades.count)") }
        return pills
    }

    private func tint(_ kind: BrainKind) -> Color {
        switch kind {
        case .keyNote: return Theme.lavender
        case .formula: return Theme.teal
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notes.isEmpty ? "Здесь пока пусто" : "Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                notes.isEmpty
                    ? "Создайте ключевую заметку с идеей и выводом или формулу с алгоритмом работы, прикрепите сделки и скриншоты."
                    : "Смените фильтр или запрос — заметки и формулы не менялись."
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}

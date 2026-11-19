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
    @State private var statusFilter: BrainStatus? = nil
    @State private var searchText = ""
    @State private var heroNote: BrainNote?
    @State private var heroExpanded = false
    @State private var heroFrame: CGRect = .zero

    private func openHero(_ note: BrainNote, from frame: CGRect) {
        heroFrame = frame
        heroNote = note
        heroExpanded = false
        Haptics.tap()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                heroExpanded = true
            }
        }
    }

    private func closeHero() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            heroExpanded = false
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 340_000_000)
            heroNote = nil
        }
    }

    private var filteredNotes: [BrainNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            if let kindFilter, note.kind != kindFilter {
                return false
            }
            if let statusFilter {
                guard note.kind.usesStatus, note.status == statusFilter else { return false }
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

    private func count(_ status: BrainStatus) -> Int {
        notes.filter { $0.kind.usesStatus && $0.status == status }.count
    }

    private var confirmedCount: Int {
        count(.confirmed)
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
                        statusFilterRow
                            .reveal(.slideLeft, 4)
                        searchRow
                            .reveal(.slideLeft, 5)
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
        .overlay {
            if let note = heroNote {
                GeometryReader { proxy in
                    let origin = proxy.frame(in: .global)
                    let start = heroFrame == .zero
                        ? CGRect(
                            x: proxy.size.width / 2 - 60,
                            y: proxy.size.height / 2 - 40,
                            width: 120,
                            height: 80
                        )
                        : heroFrame

                    ZStack {
                        Color.black
                            .opacity(heroExpanded ? 1 : 0)
                            .ignoresSafeArea()
                            .onTapGesture { closeHero() }

                        BrainNoteView(note: note, onClose: { closeHero() })
                            .mask {
                                RoundedRectangle(
                                    cornerRadius: heroExpanded ? 0 : 22,
                                    style: .continuous
                                )
                                .frame(
                                    width: heroExpanded ? proxy.size.width : max(start.width, 1),
                                    height: heroExpanded ? proxy.size.height : max(start.height, 1)
                                )
                                .position(
                                    x: heroExpanded ? proxy.size.width / 2 : start.midX - origin.minX,
                                    y: heroExpanded ? proxy.size.height / 2 : start.midY - origin.minY
                                )
                            }
                            .shadow(color: .black.opacity(heroExpanded ? 0.6 : 0), radius: 28, x: 0, y: 12)
                            .opacity(heroExpanded ? 1 : 0.15)
                            .allowsHitTesting(heroExpanded)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 40)
                                    .onEnded { value in
                                        guard heroExpanded else { return }
                                        let vertical = value.translation.height
                                        let horizontal = abs(value.translation.width)
                                        if vertical > 150, horizontal < 90, vertical > horizontal * 1.6 {
                                            closeHero()
                                        }
                                    }
                            )
                    }
                }
                .zIndex(30)
            }
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
                    .glassCircle()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "База знаний")
                ScreenTitle(text: "Second Brain")
            }

            Spacer(minLength: 8)

            pdfButton

            Menu {
                ForEach(BrainKind.allCases) { kind in
                    Button {
                        create(kind)
                    } label: {
                        Label(kind.short, systemImage: kind.icon)
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
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
                    kind: note.kind.usesStatus ? "\(note.kind.short) · \(note.status.rawValue)" : note.kind.short,
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
            SharePresenter.presentFailure()
            return
        }

        SharePresenter.share([url])
        Haptics.success()
    }

    // MARK: - Summary

    private var tiles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile("Наблюдений", "\(count(.observation))", tint: BrainKind.observation.tint)
                tile("Гипотез", "\(count(.hypothesis))", tint: BrainKind.hypothesis.tint)
                tile("Правил", "\(count(.rule))", tint: BrainKind.rule.tint)
            }
            HStack(spacing: 10) {
                tile("Закономерностей", "\(count(.pattern))", tint: BrainKind.pattern.tint)
                tile("Подтверждено", "\(confirmedCount)", tint: Theme.green)
                tile("Связано", "\(linkedTrades)", tint: Theme.textPrimary)
            }
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
                icon: BrainKind.observation.icon,
                title: "Записать наблюдение",
                subtitle: "Что заметил в поведении рынка",
                tint: BrainKind.observation.tint,
                kind: .observation
            )

            Divider()
                .overlay(Theme.hairline)

            quickRow(
                icon: BrainKind.hypothesis.icon,
                title: "Сформулировать гипотезу",
                subtitle: "Что проверить на сделках",
                tint: BrainKind.hypothesis.tint,
                kind: .hypothesis
            )

            Divider()
                .overlay(Theme.hairline)

            quickRow(
                icon: BrainKind.rule.icon,
                title: "Зафиксировать правило",
                subtitle: "Правило алгоритма входа и риска",
                tint: BrainKind.rule.tint,
                kind: .rule
            )

            Divider()
                .overlay(Theme.hairline)

            quickRow(
                icon: BrainKind.research.icon,
                title: "Начать исследование",
                subtitle: "Рыночное поведение и статистика",
                tint: BrainKind.research.tint,
                kind: .research
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
        openHero(note, from: .zero)
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

    @ViewBuilder
    private var statusFilterRow: some View {
        if count(.observation) + count(.hypothesis) + count(.rule) + count(.research) + count(.pattern) > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "Любой статус", isSelected: statusFilter == nil) {
                        statusFilter = nil
                        Haptics.select()
                    }
                    ForEach(BrainStatus.allCases) { status in
                        Chip(
                            title: "\(status.rawValue) \(count(status))",
                            isSelected: statusFilter == status,
                            tint: status.tint
                        ) {
                            statusFilter = statusFilter == status ? nil : status
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Поиск по наблюдениям, гипотезам и правилам", text: $searchText)
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
        BrainCardButton(id: "\(note.persistentModelID.hashValue)") { _, frame in
            openHero(note, from: frame)
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

                    if note.kind.usesStatus {
                        Text(note.status.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(note.status.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(note.status.tint.opacity(0.12)))
                    }

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
        .opacity(heroNote?.persistentModelID == note.persistentModelID ? 0 : 1)
    }

    private func pillTitles(_ note: BrainNote) -> [String] {
        var pills: [String] = []
        if !note.keyPoints.isEmpty { pills.append("Пунктов \(note.keyPoints.count)") }
        if !note.photos.isEmpty { pills.append("Фото \(note.photos.count)") }
        if !note.trades.isEmpty { pills.append("Сделок \(note.trades.count)") }
        return pills
    }

    private func tint(_ kind: BrainKind) -> Color {
        kind.tint
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            BreathingGlyph(systemName: notes.isEmpty ? "brain.head.profile" : "magnifyingglass")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            Text(notes.isEmpty ? "Здесь пока пусто" : "Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                notes.isEmpty
                    ? "Запишите первое наблюдение за рынком, сформулируйте гипотезу или правило алгоритма и привяжите к ним конкретные сделки."
                    : "Смените фильтр или запрос — записи базы знаний не менялись."
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


// MARK: - Кнопка карточки с её рамкой

/// Карточка базы знаний, которая знает свою рамку: из неё раскрывается заметка.
private struct BrainCardButton<Label: View>: View {
    let id: String
    let onOpen: (String, CGRect) -> Void
    private let label: Label

    @State private var frame: CGRect = .zero

    init(
        id: String,
        onOpen: @escaping (String, CGRect) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.id = id
        self.onOpen = onOpen
        self.label = label()
    }

    var body: some View {
        Button {
            onOpen(id, frame)
        } label: {
            label
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        frame = proxy.frame(in: .global)
                    }
                    .onChange(of: proxy.frame(in: .global)) { _, newValue in
                        if abs(newValue.midY - frame.midY) > 0.5 || abs(newValue.minX - frame.minX) > 0.5 {
                            frame = newValue
                        }
                    }
                    .allowsHitTesting(false)
            }
        )
    }
}

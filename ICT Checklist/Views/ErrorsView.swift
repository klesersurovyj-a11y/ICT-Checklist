//
//  ErrorsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ErrorsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ErrorNote.updatedAt, order: .reverse) private var notes: [ErrorNote]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var statusFilter: ErrorStatus? = nil
    @State private var showEditor = false
    @State private var editingNote: ErrorNote?
    @State private var noteToDelete: ErrorNote?
    @State private var selectedTrade: Trade?
    @State private var photoTarget: ErrorNote?
    @State private var showPhotoPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var summaryNote: ErrorNote?

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    private var filteredNotes: [ErrorNote] {
        guard let statusFilter else { return notes }
        return notes.filter { $0.status == statusFilter }
    }

    private func count(_ status: ErrorStatus) -> Int {
        notes.filter { $0.status == status }.count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.drop)
                    tiles
                        .reveal(.zoom, 1)
                    if !notes.isEmpty {
                        summaryCard
                            .reveal(.rise, 2)
                    }
                    statusRow
                        .reveal(.blur, 2)

                    if filteredNotes.isEmpty {
                        emptyCard
                            .reveal(.rise, 3)
                    } else {
                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                            errorCard(note)
                                .reveal(.rise, index + 3)
                        }
                    }

                    PrimaryButton(title: "Новая ошибка", icon: "plus") {
                        showEditor = true
                        Haptics.tap()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEditor) {
            ErrorEditorSheet { title, text, status in
                let note = ErrorNote(title: title, text: text, status: status)
                context.insert(note)
                try? context.save()
                Haptics.success()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(item: $editingNote) { note in
            ErrorEditorSheet(
                initialTitle: note.title,
                initialText: note.text,
                initialStatus: note.status
            ) { title, text, status in
                note.title = title
                note.text = text
                note.status = status
                note.updatedAt = .now
                try? context.save()
                Haptics.success()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
        .sheet(item: $summaryNote) { note in
            ErrorTradesSheet(note: note, usedTags: usedTags)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickedItems,
            maxSelectionCount: 8,
            matching: .images
        )
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShots(items) }
        }
        .alert("Удалить ошибку?", isPresented: deleteBinding) {
            Button("Удалить", role: .destructive) {
                if let note = noteToDelete {
                    context.delete(note)
                    try? context.save()
                    Haptics.warning()
                }
                noteToDelete = nil
            }
            Button("Отмена", role: .cancel) { noteToDelete = nil }
        } message: {
            Text("Заметка исчезнет, сделки останутся в журнале.")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )
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
                SectionLabel(text: "Работа над ошибками")
                ScreenTitle(text: "Ошибки")
            }

            Spacer(minLength: 8)

            Button {
                showEditor = true
                Haptics.tap()
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

    // MARK: - Summary

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("Ошибок", "\(notes.count)", tint: Theme.textPrimary)
            tile("Ждут результата", "\(count(.awaiting))", tint: Theme.orange)
            tile("Отработано", "\(count(.fixed))", tint: Theme.green)
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    // MARK: - Summary

    private var stats: [ErrorStat] {
        notes.map { note in
            let closed = note.trades.filter { $0.result != .open }
            let lastDate = note.trades
                .map { $0.closedAt ?? $0.tradingDay }
                .max()
            return ErrorStat(
                note: note,
                closed: closed.count,
                totalR: note.totalR,
                lastDate: lastDate
            )
        }
    }

    private var sortedStats: [ErrorStat] {
        stats.sorted { left, right in
            if abs(left.totalR - right.totalR) > 0.0001 {
                return left.totalR < right.totalR
            }
            return (left.lastDate ?? .distantPast) > (right.lastDate ?? .distantPast)
        }
    }

    private var costliestStat: ErrorStat? {
        stats.filter { $0.closed > 0 }.min { $0.totalR < $1.totalR }
    }

    private var mostRepeatedStat: ErrorStat? {
        stats.filter { $0.closed > 0 }.max { $0.closed < $1.closed }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Сводка по ошибкам")
                Spacer(minLength: 8)
                Text("по стоимости в R")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 10) {
                summaryTile(
                    title: "Самая дорогая",
                    value: costliestStat.map { Fmt.r($0.totalR) } ?? "—",
                    subtitle: costliestStat?.note.title ?? "Нет сделок",
                    tint: Theme.red
                )
                summaryTile(
                    title: "Повторяется",
                    value: mostRepeatedStat.map { "\($0.closed)" } ?? "—",
                    subtitle: mostRepeatedStat?.note.title ?? "Нет сделок",
                    tint: Theme.orange
                )
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, stat in
                    Button {
                        summaryNote = stat.note
                        Haptics.tap()
                    } label: {
                        summaryRow(stat)
                    }
                    .buttonStyle(.plain)

                    if index < sortedStats.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    private func summaryTile(
        title: String,
        value: String,
        subtitle: String,
        tint: Color
    ) -> some View {
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
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    private func summaryRow(_ stat: ErrorStat) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 32, height: 32)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.note.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(metaLine(stat))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            Text(Fmt.r(stat.totalR))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(stat.totalR))
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func metaLine(_ stat: ErrorStat) -> String {
        let trades = stat.closed == 0
            ? "нет закрытых сделок"
            : Fmt.deals(stat.closed)
        guard let lastDate = stat.lastDate else { return trades }
        return "\(trades) · последняя \(Fmt.shortDay(lastDate))"
    }

    private var statusRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Все \(notes.count)", isSelected: statusFilter == nil) {
                    statusFilter = nil
                    Haptics.select()
                }
                ForEach(ErrorStatus.allCases) { status in
                    Chip(
                        title: "\(status.rawValue) \(count(status))",
                        isSelected: statusFilter == status,
                        tint: statusTint(status)
                    ) {
                        statusFilter = statusFilter == status ? nil : status
                        Haptics.select()
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Cards

    private func errorCard(_ note: ErrorNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(note.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                statusMenu(note)
            }

            Text(metaLine(note))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            tradesBlock(note)
            shotsBlock(note)

            HStack(spacing: 8) {
                Button {
                    editingNote = note
                    Haptics.tap()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Изменить")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    noteToDelete = note
                    Haptics.tap()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 28, height: 28)
                        .glassCircle()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func metaLine(_ note: ErrorNote) -> String {
        var parts: [String] = ["создано \(Fmt.shortDay(note.createdAt))"]
        if note.trades.isEmpty {
            parts.append("сделок нет")
        } else {
            parts.append("\(Fmt.deals(note.trades.count)) · \(Fmt.r(note.totalR))")
        }
        return parts.joined(separator: " · ")
    }

    private func statusMenu(_ note: ErrorNote) -> some View {
        Menu {
            ForEach(ErrorStatus.allCases) { status in
                Button {
                    note.status = status
                    note.updatedAt = .now
                    try? context.save()
                    Haptics.select()
                } label: {
                    Text(status.rawValue)
                }
            }
        } label: {
            Text(note.status.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusTint(note.status))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(statusTint(note.status).opacity(0.14)))
                .overlay(
                    Capsule().strokeBorder(statusTint(note.status).opacity(0.32), lineWidth: 1)
                )
        }
    }

    private func statusTint(_ status: ErrorStatus) -> Color {
        switch status {
        case .awaiting: return Theme.orange
        case .fixed: return Theme.green
        case .repeated: return Theme.red
        }
    }

    // MARK: - Attached trades

    private func tradesBlock(_ note: ErrorNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("СДЕЛКИ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)

                Spacer(minLength: 8)

                Menu {
                    let list = candidates(note)
                    if list.isEmpty {
                        Text("Нет свободных сделок")
                    } else {
                        ForEach(list) { trade in
                            Button {
                                attach(trade, to: note)
                            } label: {
                                Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.symbol) · \(trade.result.rawValue)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Прикрепить")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
            }

            if note.sortedTrades.isEmpty {
                Text("Пока ничего не прикреплено")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(note.sortedTrades) { trade in
                    tradeRow(trade, note: note)
                }
            }
        }
    }

    private func tradeRow(_ trade: Trade, note: ErrorNote) -> some View {
        HStack(spacing: 8) {
            Button {
                selectedTrade = trade
                Haptics.tap()
            } label: {
                HStack(spacing: 8) {
                    Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.symbol) · \(trade.result.rawValue)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rColor(trade.actualR))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                detach(trade, from: note)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20, height: 20)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func candidates(_ note: ErrorNote) -> [Trade] {
        let attached = Set(note.trades.map { $0.persistentModelID })
        return trades
            .filter { $0.result != .open }
            .filter { !attached.contains($0.persistentModelID) }
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

    private func attach(_ trade: Trade, to note: ErrorNote) {
        note.attach(trade)
        try? context.save()
        Haptics.tap()
    }

    private func detach(_ trade: Trade, from note: ErrorNote) {
        note.detach(trade)
        try? context.save()
        Haptics.tap()
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Screenshots

    private func shotsBlock(_ note: ErrorNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("СКРИНШОТЫ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)

                Spacer(minLength: 8)

                Button {
                    photoTarget = note
                    showPhotoPicker = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Добавить")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            if note.sortedShots.isEmpty {
                Text("Пока нет скриншотов")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.sortedShots) { shot in
                            ZStack(alignment: .topTrailing) {
                                ErrorShotThumbnail(shot: shot, size: 64)

                                Button {
                                    deleteShot(shot, note: note)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 6)
                }
            }
        }
    }

    private func importShots(_ items: [PhotosPickerItem]) async {
        guard let note = photoTarget else {
            pickedItems = []
            return
        }

        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                images.append(data)
            }
        }

        for data in images {
            let shot = ErrorShot(imageData: data)
            context.insert(shot)
            note.shots.append(shot)
        }

        if !images.isEmpty {
            note.updatedAt = .now
            try? context.save()
            Haptics.success()
        }

        pickedItems = []
        photoTarget = nil
    }

    private func deleteShot(_ shot: ErrorShot, note: ErrorNote) {
        note.shots.removeAll { $0 === shot }
        context.delete(shot)
        note.updatedAt = .now
        try? context.save()
        Haptics.tap()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            BreathingGlyph(systemName: notes.isEmpty ? "exclamationmark.triangle" : "magnifyingglass")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            Text(notes.isEmpty ? "Ошибок пока нет" : "Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                notes.isEmpty
                    ? "Запишите ошибку, прикрепите сделки, где она повторилась, и отметьте, какого результата ждёте после отработки."
                    : "Смените фильтр по статусу — сами ошибки не менялись."
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

// MARK: - Thumbnail

private struct ErrorShotThumbnail: View {
    let shot: ErrorShot
    var size: CGFloat = 64

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: shot.imageData?.count) {
            image = shot.imageData.flatMap(UIImage.init(data:))
        }
    }
}

// MARK: - Editor
private struct ErrorEditorSheet: View {
    var initialTitle: String = ""
    var initialText: String = ""
    var initialStatus: ErrorStatus = .awaiting

    let onSave: (String, String, ErrorStatus) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var text = ""
    @State private var status: ErrorStatus = .awaiting
    @State private var didLoad = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Работа над ошибками")
                            Text(initialTitle.isEmpty ? "Новая ошибка" : "Ошибка")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer(minLength: 8)
                        Button("Закрыть") {
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ЧТО ЗА ОШИБКА")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        TextField("Например: вход против тренда", text: $title, axis: .vertical)
                            .lineLimit(1...2)
                            .font(.system(size: 15))
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
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("КАКОЙ РЕЗУЛЬТАТ ЖДЁТЕ")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        GlassNoteField(
                            placeholder: "Что произошло, что проверю в следующий раз",
                            text: $text,
                            limit: 600,
                            lines: 3...8,
                            minHeight: 120
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("СТАТУС")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ErrorStatus.allCases) { item in
                                    Chip(
                                        title: item.rawValue,
                                        isSelected: status == item,
                                        tint: tint(status)
                                    ) {
                                        status = item
                                        Haptics.select()
                                    }
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }

                    PrimaryButton(title: "Сохранить", isEnabled: canSave) {
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            text,
                            status
                        )
                        dismiss()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            title = initialTitle
            text = initialText
            status = initialStatus
        }
    }

    private func tint(_ status: ErrorStatus) -> Color {
        switch status {
        case .awaiting: return Theme.orange
        case .fixed: return Theme.green
        case .repeated: return Theme.red
        }
    }
}



// MARK: - Summary model

private struct ErrorStat: Identifiable {
    let note: ErrorNote
    let closed: Int
    let totalR: Double
    let lastDate: Date?

    var id: PersistentIdentifier { note.id }
}

// MARK: - Error trades sheet

private struct ErrorTradesSheet: View {
    let note: ErrorNote
    let usedTags: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTrade: Trade?

    private var trades: [Trade] {
        note.trades.sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

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
                    header
                    summary
                    tradeList
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Ошибка")
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
    }

    private var summary: some View {
        HStack(spacing: 8) {
            Text(note.status.rawValue)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(tint.opacity(0.14)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1))

            Text("\(Fmt.deals(trades.count)) · \(Fmt.r(note.totalR))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    @ViewBuilder
    private var tradeList: some View {
        if trades.isEmpty {
            Text("К этой ошибке не прикреплено ни одной сделки.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 20)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                    Button {
                        selectedTrade = trade
                        Haptics.tap()
                    } label: {
                        tradeRow(trade)
                    }
                    .buttonStyle(.plain)

                    if index < trades.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    private func tradeRow(_ trade: Trade) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.shortDay(trade.tradingDay))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Text(trade.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(trade.result.rawValue)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(resultTint(trade.result))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(resultTint(trade.result).opacity(0.16)))

            Spacer(minLength: 6)

            Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(trade.actualR))

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func resultTint(_ result: TradeResult) -> Color {
        switch result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return Theme.textSecondary
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

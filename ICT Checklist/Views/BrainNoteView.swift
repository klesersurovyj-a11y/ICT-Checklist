//
//  BrainNoteView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct BrainNoteView: View {
    @Bindable var note: BrainNote

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var keyLines: [KeyLine] = []
    @State private var didLoadKey = false
    @State private var showDeleteConfirm = false
    @State private var selectedTrade: Trade?
    @State private var showPhotoPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isDeleted = false

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    private var tint: Color {
        note.kind == .keyNote ? Theme.lavender : Theme.teal
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.slideLeft)
                    kindRow
                        .reveal(.blur, 1)
                    titleBlock
                        .reveal(.drop, 2)
                    descriptionCard
                        .reveal(.rise, 3)
                    keyCard
                        .reveal(.rise, 4)
                    benefitsCard
                    schematicCard
                    chartsCard
                    conclusionsCard
                    tradesCard
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickedItems,
            maxSelectionCount: 8,
            matching: .images
        )
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .onChange(of: keyLines) { _, _ in
            guard didLoadKey else { return }
            syncKeyLines()
        }
        .onAppear(perform: loadKeyLines)
        .onDisappear(perform: persist)
        .alert("Удалить запись?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                isDeleted = true
                context.delete(note)
                try? context.save()
                Haptics.warning()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Заметка, её скриншоты и связи со сделками будут удалены.")
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                persist()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Second Brain")
                ScreenTitle(text: note.kind.short)
            }

            Spacer(minLength: 8)

            Button {
                showDeleteConfirm = true
                Haptics.tap()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
    }

    private var kindRow: some View {
        GlassSegmented(
            options: BrainKind.allCases,
            selection: Binding(
                get: { note.kind },
                set: { kind in
                    note.kind = kind
                    persist()
                    Haptics.select()
                }
            ),
            label: { $0.short },
            tint: { $0 == .keyNote ? Theme.lavender : Theme.teal }
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(note.kind.placeholderTitle, text: $note.title, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tint(Theme.accent)

            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)

                TextField("Тема", text: $note.topic)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .textInputAutocapitalization(.sentences)
            }

            Text("Создано \(Fmt.shortDay(note.createdAt)) · изменено \(Fmt.shortDay(note.updatedAt))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sections

    private var descriptionCard: some View {
        sectionCard("Описание", icon: "text.alignleft") {
            GlassNoteField(
                placeholder: "О чём заметка, что произошло, что увидел",
                text: $note.summary,
                limit: 1500,
                lines: 3...10,
                minHeight: 110
            )
        }
    }

    private var keyCard: some View {
        sectionCard(note.kind.keyTitle, icon: "key") {
            VStack(alignment: .leading, spacing: 8) {
                if keyLines.isEmpty {
                    Text("Добавьте пункты — каждый станет отдельной строкой списка.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }

                ForEach($keyLines) { $line in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)

                        TextField("Пункт", text: $line.text, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .tint(Theme.accent)

                        Button {
                            if let index = keyLines.firstIndex(where: { $0.id == line.id }) {
                                keyLines.remove(at: index)
                                Haptics.tap()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }

                Button {
                    keyLines.append(KeyLine(text: ""))
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Добавить пункт")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var benefitsCard: some View {
        sectionCard("Преимущества", icon: "sparkles") {
            GlassNoteField(
                placeholder: "Что это даёт в торговле",
                text: $note.benefits,
                limit: 800,
                lines: 2...6,
                minHeight: 70
            )
        }
    }

    private var schematicCard: some View {
        sectionCard("Схема", icon: "rectangle.connected.to.line.below") {
            GlassNoteField(
                placeholder: "Как это работает по шагам",
                text: $note.schematic,
                limit: 1200,
                lines: 3...8,
                minHeight: 90
            )
        }
    }

    private var chartsCard: some View {
        sectionCard("Примеры графиков", icon: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 10) {
                if note.sortedPhotos.isEmpty {
                    Text("Прикрепите скриншоты терминала")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.sortedPhotos) { photo in
                                ZStack(alignment: .topTrailing) {
                                    BrainShotThumbnail(shot: photo, size: 68)

                                    Button {
                                        deletePhoto(photo)
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

                Button {
                    showPhotoPicker = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Добавить скриншоты")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)

                GlassNoteField(
                    placeholder: "Что видно на графиках",
                    text: $note.chartExamples,
                    limit: 800,
                    lines: 2...6,
                    minHeight: 60
                )
            }
        }
    }

    private var conclusionsCard: some View {
        sectionCard("Выводы", icon: "checkmark.seal") {
            GlassNoteField(
                placeholder: "Что берём в работу",
                text: $note.conclusions,
                limit: 800,
                lines: 2...6,
                minHeight: 70
            )
        }
    }

    private func sectionCard<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Trades

    private var tradesCard: some View {
        sectionCard("Сделки", icon: "link") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("СВЯЗАННЫЕ СДЕЛКИ")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)

                    Spacer(minLength: 8)

                    Menu {
                        let list = candidates()
                        if list.isEmpty {
                            Text("Нет свободных сделок")
                        } else {
                            ForEach(list) { trade in
                                Button {
                                    note.attach(trade)
                                    try? context.save()
                                    Haptics.tap()
                                } label: {
                                    Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.symbol) · \(trade.result.rawValue)")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Добавить")
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
                        tradeRow(trade)
                    }
                }
            }
        }
    }

    private func tradeRow(_ trade: Trade) -> some View {
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
                note.detach(trade)
                try? context.save()
                Haptics.tap()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func candidates() -> [Trade] {
        let attached = Set(note.trades.map { $0.persistentModelID })
        return trades
            .filter { !attached.contains($0.persistentModelID) }
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                Text("Удалить запись")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.red.opacity(0.12))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 6)
    }

    // MARK: - Storage

    private func loadKeyLines() {
        guard !didLoadKey else { return }
        didLoadKey = true
        keyLines = note.keyPoints.map { KeyLine(text: $0) }
        if keyLines.isEmpty {
            keyLines = [KeyLine(text: "")]
        }
    }

    private func syncKeyLines() {
        let values = keyLines
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        note.keyRaw = values.joined(separator: "\n")
        note.updatedAt = .now
        try? context.save()
    }

    private func persist() {
        guard !isDeleted else { return }
        if didLoadKey {
            syncKeyLines()
        } else {
            note.updatedAt = .now
            try? context.save()
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                images.append(data)
            }
        }

        for data in images {
            let shot = BrainShot(imageData: data)
            context.insert(shot)
            note.photos.append(shot)
        }

        if !images.isEmpty {
            note.updatedAt = .now
            try? context.save()
            Haptics.success()
        }

        pickedItems = []
    }

    private func deletePhoto(_ photo: BrainShot) {
        note.photos.removeAll { $0 === photo }
        context.delete(photo)
        note.updatedAt = .now
        try? context.save()
        Haptics.tap()
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Key line

private struct KeyLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

// MARK: - Photo thumbnail

private struct BrainShotThumbnail: View {
    let shot: BrainShot
    var size: CGFloat = 68

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

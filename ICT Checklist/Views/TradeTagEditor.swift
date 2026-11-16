//
//  TradeTagEditor.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import PhotosUI

struct TradeTagEditor: View {
    @Bindable var trade: Trade
    let usedTags: [String]

    @Environment(\.modelContext) private var context
    @State private var newTag = ""
    @State private var pickedItems: [PhotosPickerItem] = []

    private var suggestions: [String] {
        usedTags.filter { tag in
            !trade.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
    }

    private var canAdd: Bool {
        let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        return !trade.tags.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("МЕТКИ")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            if trade.tags.isEmpty {
                Text("Меток пока нет — добавьте свою или выберите использованную.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trade.tags, id: \.self) { tag in
                            selectedChip(tag)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { tag in
                            Button {
                                addTag(tag)
                            } label: {
                                Text(tag)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            HStack(spacing: 8) {
                TextField("Новая метка, например «A+ setup»", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(Theme.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .onSubmit { addTag(newTag) }

                Button {
                    addTag(newTag)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(canAdd ? Theme.blue : Theme.blue.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .onChange(of: newTag) { _, value in
                if value.count > 24 {
                    newTag = String(value.prefix(24))
                }
            }

            shotsSection
        }
    }

    // MARK: - Screenshots

    private var shotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Скриншоты")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trade.sortedShots) { shot in
                        ShotThumbnail(fileName: shot.fileName, size: 58)
                            .contextMenu {
                                Button("Удалить", role: .destructive) {
                                    removeShot(shot)
                                }
                            }
                    }

                    PhotosPicker(
                        selection: $pickedItems,
                        maxSelectionCount: 8,
                        matching: .images
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.14),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 58, height: 58)
                    }
                }
                .padding(.vertical, 1)
            }

            if trade.shots.isEmpty {
                Text("Прикрепите снимок терминала — он хранится только на этом устройстве.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShots(items) }
        }
    }

    private func importShots(_ items: [PhotosPickerItem]) async {
        var names: [String] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = try? ScreenshotStore.save(data: data) {
                names.append(name)
            }
        }
        guard !names.isEmpty else {
            pickedItems = []
            return
        }
        for name in names {
            let shot = TradeShot(fileName: name)
            context.insert(shot)
            trade.shots.append(shot)
        }
        try? context.save()
        pickedItems = []
        Haptics.success()
    }

    private func removeShot(_ shot: TradeShot) {
        ScreenshotStore.delete(shot.fileName)
        trade.shots.removeAll { $0 === shot }
        context.delete(shot)
        try? context.save()
        Haptics.tap()
    }

    private func selectedChip(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Button {
                removeTag(tag)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.blue.opacity(0.20)))
        .overlay(Capsule().strokeBorder(Theme.blue.opacity(0.4), lineWidth: 1))
    }

    private func addTag(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard !trade.tags.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            newTag = ""
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            trade.tags.append(value)
        }
        newTag = ""
        try? context.save()
        Haptics.tap()
    }

    private func removeTag(_ tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            trade.tags.removeAll { $0 == tag }
        }
        try? context.save()
        Haptics.tap()
    }
}

struct TradeTagsSheet: View {
    let trade: Trade
    let usedTags: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Метки")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                }

                HStack(spacing: 8) {
                    Text(trade.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(trade.direction.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                        )
                    Text(Fmt.shortDay(trade.tradingDay))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 0)
                }

                TradeTagEditor(trade: trade, usedTags: usedTags)
            }
            .padding(22)
        }
    }
}

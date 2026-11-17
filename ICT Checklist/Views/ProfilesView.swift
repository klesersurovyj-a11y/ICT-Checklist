//
//  ProfilesView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

enum ProfilePalette {
    static let colors: [Int] = [0xE4E4E4, 0x7BE3B0, 0x1FB6A8, 0xD6D6D6, 0xFF8A8A]

    static func color(for index: Int) -> Int {
        guard !colors.isEmpty else { return 0xE4E4E4 }
        return colors[index % colors.count]
    }
}

struct ProfilesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TraderProfile.createdAt) private var profiles: [TraderProfile]
    @Query private var settingsList: [AppSettings]

    @State private var search = ""
    @State private var showEditor = false
    @State private var editingProfile: TraderProfile?
    @State private var profileToDelete: TraderProfile?

    private var activeProfile: TraderProfile? {
        profiles.first { $0.isActive }
    }

    private var filtered: [TraderProfile] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return profiles }

        return profiles.filter { profile in
            profile.name.lowercased().contains(query)
                || profile.style.rawValue.lowercased().contains(query)
                || profile.systemName.lowercased().contains(query)
                || profile.symbols.joined(separator: " ").lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.slideLeft)
                    summaryTiles
                        .reveal(.zoom, 1)
                    searchField
                        .reveal(.blur, 2)

                    if profiles.isEmpty {
                        emptyCard
                            .reveal(.rise, 3)
                    } else if filtered.isEmpty {
                        InfoHint(text: "Ничего не нашлось — попробуйте другой запрос.")
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, profile in
                            profileCard(profile)
                                .reveal(.rise, index + 3)
                        }
                    }

                    addButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEditor) {
            ProfileEditorSheet(
                initial: ProfileDraft(colorHex: ProfilePalette.color(for: profiles.count)),
                title: "Новый профиль"
            ) { draft in
                create(draft)
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorSheet(
                initial: ProfileDraft(profile: profile),
                title: "Профиль"
            ) { draft in
                update(draft, profile: profile)
            }
        }
        .alert("Удалить профиль?", isPresented: deleteBinding) {
            Button("Удалить", role: .destructive) {
                if let profile = profileToDelete {
                    delete(profile)
                }
                profileToDelete = nil
            }
            Button("Отмена", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("Профиль исчезнет из базы. Сделки и счета останутся как есть.")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
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
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Профили")
                ScreenTitle(text: "База профилей")
            }

            Spacer(minLength: 8)
        }
    }

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            tile("Профилей", "\(profiles.count)", tint: Theme.textPrimary)
            tile("Активный", activeProfile?.title ?? "—", tint: Theme.accent)
            tile("Система", activeProfile?.systemName ?? "—", tint: Theme.green)
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)

            TextField("Поиск профиля", text: $search)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Cards

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(Theme.accent)
            Text("Пока нет профилей")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Создайте профиль — система, риск и рабочие символы будут храниться вместе с ним.")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private func profileCard(_ profile: TraderProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatar(for: profile)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if profile.isActive {
                            Text("АКТИВЕН")
                                .font(.system(size: 8.5, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.accent))
                        }
                    }

                    Text(profile.style.rawValue)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        activate(profile)
                    } label: {
                        Label("Сделать активным", systemImage: "checkmark.circle")
                    }
                    Button {
                        editingProfile = profile
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        profileToDelete = profile
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
            }

            HStack(spacing: 6) {
                tag(profile.systemName.isEmpty ? "Система" : profile.systemName)
                tag("RR \(Fmt.rr(profile.minRR))")
                tag("\(Fmt.money(profile.ladder1)) риск")
            }

            if !profile.symbols.isEmpty {
                Text(profile.symbols.joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            if !profile.notes.isEmpty {
                Text(profile.notes)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func avatar(for profile: TraderProfile) -> some View {
        let tint = Color(hex: UInt32(max(profile.colorHex, 0)))

        return ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 44, height: 44)
            Circle()
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
                .frame(width: 44, height: 44)
            Text(profile.initials.isEmpty ? "·" : profile.initials)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    private var addButton: some View {
        Button {
            showEditor = true
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Добавить профиль")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Actions

    private func create(_ draft: ProfileDraft) {
        let profile = TraderProfile(name: draft.trimmedName, style: draft.style)
        apply(draft, to: profile)
        if profiles.isEmpty {
            profile.isActive = true
        }

        context.insert(profile)
        save()
        Haptics.success()
    }

    private func update(_ draft: ProfileDraft, profile: TraderProfile) {
        profile.name = draft.trimmedName
        apply(draft, to: profile)
        profile.updatedAt = .now
        save()
        Haptics.success()
    }

    private func apply(_ draft: ProfileDraft, to profile: TraderProfile) {
        profile.style = draft.style
        profile.symbols = draft.symbols
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        profile.systemName = draft.trimmedSystem
        profile.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.colorHex = draft.colorHex
        profile.minRR = draft.minRR
        profile.ladder1 = draft.ladder1
        profile.ladder2 = draft.ladder2
        profile.ladder3 = draft.ladder3
        profile.maxTradesPerDay = draft.maxTrades
        profile.maxDailyLossR = draft.maxLossR
    }

    private func activate(_ profile: TraderProfile) {
        withAnimation(Theme.snappy) {
            TraderProfile.setActive(profile, in: profiles)
        }

        let settings: AppSettings
        if let existing = settingsList.first {
            settings = existing
        } else {
            let created = AppSettings()
            context.insert(created)
            settings = created
        }

        profile.apply(to: settings)
        profile.updatedAt = .now
        save()
        WidgetSnapshot.refresh(context: context)
        Haptics.success()
    }

    private func delete(_ profile: TraderProfile) {
        let wasActive = profile.isActive
        context.delete(profile)
        try? context.save()

        if wasActive, let next = profiles.first(where: { $0.persistentModelID != profile.persistentModelID }) {
            next.isActive = true
            try? context.save()
        }

        Haptics.warning()
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - Draft

private struct ProfileDraft {
    var name: String = ""
    var style: TraderStyle = .intraday
    var symbols: String = "EURUSD,GBPUSD,XAUUSD"
    var systemName: String = "TDA + Risk"
    var notes: String = ""
    var colorHex: Int = 0xE4E4E4
    var minRR: Double = 2
    var ladder1: Double = 12
    var ladder2: Double = 25
    var ladder3: Double = 50
    var maxTrades: Int = 2
    var maxLossR: Double = 2

    init(colorHex: Int = 0xE4E4E4) {
        self.colorHex = colorHex
    }

    init(profile: TraderProfile) {
        name = profile.name
        style = profile.style
        symbols = profile.symbolsRaw
        systemName = profile.systemName
        notes = profile.notes
        colorHex = profile.colorHex
        minRR = profile.minRR
        ladder1 = profile.ladder1
        ladder2 = profile.ladder2
        ladder3 = profile.ladder3
        maxTrades = profile.maxTradesPerDay
        maxLossR = profile.maxDailyLossR
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSystem: String {
        let text = systemName.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "TDA + Risk" : text
    }
}

// MARK: - Editor

private struct ProfileEditorSheet: View {
    let initial: ProfileDraft
    let title: String
    let onSave: (ProfileDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: ProfileDraft

    init(initial: ProfileDraft, title: String, onSave: @escaping (ProfileDraft) -> Void) {
        self.initial = initial
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    private var canSave: Bool {
        !draft.trimmedName.isEmpty
    }

    private var tradesBinding: Binding<Double> {
        Binding(
            get: { Double(draft.maxTrades) },
            set: { draft.maxTrades = max(1, Int($0.rounded())) }
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }

                    SectionLabel(text: "Имя")
                    SingleLineField(placeholder: "Например, Кирилл", text: $draft.name)

                    SectionLabel(text: "Стиль")
                    styleChips

                    SectionLabel(text: "Система")
                    SingleLineField(placeholder: "TDA + Risk", text: $draft.systemName)

                    SectionLabel(text: "Символы")
                    SingleLineField(placeholder: "EURUSD,GBPUSD,XAUUSD", text: $draft.symbols)

                    SectionLabel(text: "Риск")
                    VStack(alignment: .leading, spacing: 10) {
                        NumberRow(title: "Минимальный RR", value: $draft.minRR, range: 1...5, step: 0.1, digits: 1)
                        NumberRow(title: "Ступень 1", prefix: "$", value: $draft.ladder1, range: 1...100000, step: 1, digits: 0)
                        NumberRow(title: "Ступень 2", prefix: "$", value: $draft.ladder2, range: 1...100000, step: 1, digits: 0)
                        NumberRow(title: "Ступень 3", prefix: "$", value: $draft.ladder3, range: 1...100000, step: 1, digits: 0)
                        NumberRow(title: "Сделок в день", value: tradesBinding, range: 1...20, step: 1, digits: 0)
                        NumberRow(
                            title: "Лимит убытка",
                            prefix: "\u{2212}",
                            suffix: "R",
                            value: $draft.maxLossR,
                            range: 0.5...10,
                            step: 0.5,
                            digits: 1
                        )
                    }

                    SectionLabel(text: "Цвет")
                    colorChips

                    SectionLabel(text: "Заметки")
                    GlassNoteField(
                        placeholder: "О себе, счёт, особенности",
                        text: $draft.notes,
                        limit: 300,
                        lines: 3...6
                    )

                    PrimaryButton(title: "Сохранить", icon: "checkmark", isEnabled: canSave) {
                        onSave(draft)
                        Haptics.success()
                        dismiss()
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    private var styleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TraderStyle.allCases) { style in
                    Chip(title: style.rawValue, isSelected: draft.style == style) {
                        draft.style = style
                        Haptics.select()
                    }
                }
            }
        }
    }

    private var colorChips: some View {
        HStack(spacing: 10) {
            ForEach(ProfilePalette.colors, id: \.self) { hex in
                Button {
                    draft.colorHex = hex
                    Haptics.select()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: UInt32(max(hex, 0))))
                            .frame(width: 24, height: 24)
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(draft.colorHex == hex ? 0.9 : 0),
                                lineWidth: 2
                            )
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

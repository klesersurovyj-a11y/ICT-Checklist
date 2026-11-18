//
//  SystemView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct SystemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var blueprint: SystemBlueprint?

    var body: some View {
        ZStack {
            AppBackground()

            if let blueprint {
                SystemContent(blueprint: blueprint) {
                    dismiss()
                }
            }
        }
        .task {
            guard blueprint == nil else { return }
            blueprint = SystemBlueprint.loadOrCreate(context: context)
        }
    }
}

// MARK: - Content

private struct SystemContent: View {
    @Bindable var blueprint: SystemBlueprint
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]

    @State private var stages: [SystemStage]
    @State private var editingStage: SystemStage?
    @State private var isAddingStage = false
    @State private var appliedText: String?
    @State private var showAssistant = false

    init(blueprint: SystemBlueprint, onClose: @escaping () -> Void) {
        self.blueprint = blueprint
        self.onClose = onClose
        _stages = State(initialValue: blueprint.stages)
    }

    private var enabledCount: Int {
        stages.filter(\.isEnabled).count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                backButton
                    .reveal(.slideLeft)
                header
                    .reveal(.drop)
                skeletonCard
                    .reveal(.blur, 1)
                stagesCard
                    .reveal(.rise, 2)
                riskCard
                    .reveal(.rise, 3)
                applyCard
                    .reveal(.rise, 4)
                assistantCard
                    .reveal(.rise, 5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(item: $editingStage) { stage in
            StageEditorSheet(stage: stage, title: "Этап системы") { updated in
                guard let index = stages.firstIndex(where: { $0.id == updated.id }) else { return }
                stages[index] = updated
                persistStages()
            }
        }
        .sheet(isPresented: $isAddingStage) {
            StageEditorSheet(stage: SystemStage.newStage(), title: "Новый этап") { created in
                stages.append(created)
                persistStages()
            }
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: "Проверь мою торговую систему: где логические дыры, что противоречит костяку TDA + Risk и что исправить в первую очередь.")
        }
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            onClose()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Назад")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Торговая система")
            ScreenTitle(text: "Конструктор")
            Text("Костяк: TDA + Risk. Этапы ведут от недельного контекста к входу, риск задан числом.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Skeleton

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Костяк")

            SingleLineField(placeholder: "Название системы", text: $blueprint.name)

            HStack(spacing: 8) {
                statPill(title: "ЭТАПЫ", value: "\(enabledCount)/\(stages.count)")
                statPill(title: "MIN RR", value: Fmt.rr(blueprint.minRR))
                statPill(title: "РИСК 1", value: Fmt.money(blueprint.ladder1))
            }

            SecondaryButton(title: "Сбросить к TDA + Risk") {
                reset()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Stages

    private var stagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "Топ-даун анализ")
                Spacer(minLength: 8)
                Button {
                    isAddingStage = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Этап")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if stages.isEmpty {
                InfoHint(text: "Добавьте этапы — по ним собирается система.")
            } else {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    StageRow(
                        index: index + 1,
                        stage: stage,
                        isOn: stageBinding(stage),
                        onEdit: { editingStage = stage },
                        onDelete: { delete(stage) }
                    )
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func stageBinding(_ stage: SystemStage) -> Binding<Bool> {
        Binding(
            get: { stages.first { $0.id == stage.id }?.isEnabled ?? stage.isEnabled },
            set: { newValue in
                guard let index = stages.firstIndex(where: { $0.id == stage.id }) else { return }
                stages[index].isEnabled = newValue
                persistStages()
                Haptics.select()
            }
        )
    }

    // MARK: - Risk model

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Риск-модель")

            NumberRow(title: "Ступень 1", prefix: "$", value: $blueprint.ladder1, range: 1...100000, step: 1, digits: 0)
            NumberRow(title: "Ступень 2", prefix: "$", value: $blueprint.ladder2, range: 1...100000, step: 1, digits: 0)
            NumberRow(title: "Ступень 3", prefix: "$", value: $blueprint.ladder3, range: 1...100000, step: 1, digits: 0)

            Divider()
                .overlay(Theme.hairline)

            NumberRow(title: "Минимальный RR", value: $blueprint.minRR, range: 1...5, step: 0.1, digits: 1)
            NumberRow(title: "Сделок в день", value: tradesBinding, range: 1...20, step: 1, digits: 0)
            NumberRow(
                title: "Лимит убытка",
                prefix: "\u{2212}",
                suffix: "R",
                value: $blueprint.maxDailyLossR,
                range: 0.5...10,
                step: 0.5,
                digits: 1
            )

            ToggleRow(
                title: "Лимиты дня",
                subtitle: "Новых входов нет, пока не начнётся следующий цикл",
                isOn: $blueprint.dailyLimitsEnabled
            )
            .padding(.top, 4)

            Text("+2R внутри ступени — переход выше. SL — сброс на первую ступень.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var tradesBinding: Binding<Double> {
        Binding(
            get: { Double(blueprint.maxTradesPerDay) },
            set: { blueprint.maxTradesPerDay = max(1, Int($0.rounded())) }
        )
    }

    // MARK: - Apply

    private var applyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Применить")

            SummaryTable(items: [
                SummaryItem(title: "Минимальный RR", value: Fmt.rr(blueprint.minRR)),
                SummaryItem(title: "Риск на сделку", value: Fmt.money(blueprint.ladder1)),
                SummaryItem(title: "Сделок в день", value: "\(blueprint.maxTradesPerDay)"),
                SummaryItem(title: "Лимит убытка", value: Fmt.r(-blueprint.maxDailyLossR))
            ])

            PrimaryButton(title: "Применить к настройкам", icon: "checkmark") {
                apply()
            }

            Text("Переносит риск-модель в настройки цикла: RR-проверка, ступени лэддера и лимиты дня начинают работать по системе.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let appliedText {
                Text(appliedText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Assistant

    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Разбор")
            Text("Ассистент видит этапы системы, риск-модель, профили и последние сделки.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Спросить ИИ про систему") {
                showAssistant = true
                Haptics.tap()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Actions

    private func persistStages() {
        blueprint.stages = stages
        blueprint.updatedAt = .now
        save()
    }

    private func save() {
        try? context.save()
    }

    private func reset() {
        stages = SystemStage.tdaPreset
        persistStages()
        appliedText = nil
        Haptics.tap()
    }

    private func delete(_ stage: SystemStage) {
        stages.removeAll { $0.id == stage.id }
        persistStages()
        Haptics.warning()
    }

    private func apply() {
        let settings: AppSettings
        if let existing = settingsList.first {
            settings = existing
        } else {
            let created = AppSettings()
            context.insert(created)
            settings = created
        }

        settings.minRR = blueprint.minRR
        settings.ladder1 = blueprint.ladder1
        settings.ladder2 = blueprint.ladder2
        settings.ladder3 = blueprint.ladder3
        settings.maxTradesPerDay = blueprint.maxTradesPerDay
        settings.maxDailyLossR = blueprint.maxDailyLossR
        settings.dailyLimitsEnabled = blueprint.dailyLimitsEnabled

        try? context.save()
        WidgetSnapshot.refresh(context: context)

        appliedText = "Применено к настройкам"
        Haptics.success()
    }
}

// MARK: - Stage row

private struct StageRow: View {
    let index: Int
    let stage: SystemStage
    @Binding var isOn: Bool

    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOn ? Theme.accent.opacity(0.16) : Color.white.opacity(0.05))
                    .frame(width: 26, height: 26)
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isOn ? Theme.accent : Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.textPrimary : Theme.textTertiary)
                    .multilineTextAlignment(.leading)

                let subtitle = stage.rule.isEmpty ? stage.detail : stage.rule
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Stage editor

private struct StageEditorSheet: View {
    let stage: SystemStage
    let title: String
    let onSave: (SystemStage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var stageTitle: String = ""
    @State private var detail: String = ""
    @State private var rule: String = ""

    private var canSave: Bool {
        !stageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

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
                            .glassCircle()
                    }
                    .buttonStyle(.plain)
                }

                SingleLineField(placeholder: "Название этапа", text: $stageTitle)
                SingleLineField(placeholder: "Что проверяю", text: $detail)

                GlassNoteField(placeholder: "Правило системы", text: $rule, limit: 240, lines: 3...6)

                Spacer(minLength: 0)

                PrimaryButton(title: "Сохранить", icon: "checkmark", isEnabled: canSave) {
                    var updated = stage
                    updated.title = stageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.rule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(updated)
                    Haptics.success()
                    dismiss()
                }
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
        .onAppear {
            stageTitle = stage.title
            detail = stage.detail
            rule = stage.rule
        }
    }
}

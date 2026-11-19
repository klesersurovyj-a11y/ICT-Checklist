//
//  AdviceJournalView.swift
//  ICT Checklist
//
//  Советы: гипотезы из разборов ассистента и их проверка в сделках.
//

import SwiftUI
import SwiftData

struct AdviceJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \AdviceHypothesis.createdAt, order: .reverse)
    private var hypotheses: [AdviceHypothesis]

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var editing: AdviceHypothesis?

    private var drafts: [AdviceHypothesis] {
        hypotheses.filter { $0.status == .draft }
    }

    private var testing: [AdviceHypothesis] {
        hypotheses.filter { $0.status == .testing }
    }

    private var closed: [AdviceHypothesis] {
        hypotheses.filter { $0.status == .confirmed || $0.status == .rejected }
    }

    private var dueCount: Int {
        testing.filter { AdviceJournal.progress(for: $0, trades: trades).isDue }.count
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

                    if hypotheses.isEmpty {
                        emptyCard
                            .reveal(.rise, 1)
                    } else {
                        if dueCount > 0 {
                            dueCard
                                .reveal(.zoom, 1)
                        }
                        section("Проверяется", items: testing, empty: "Гипотез на проверке нет.", tint: Theme.accent)
                        section("Черновики", items: drafts, empty: "Черновиков нет.", tint: Theme.orange)
                        if !closed.isEmpty {
                            section("Закрытые", items: closed, empty: "", tint: Theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(item: $editing) { hypothesis in
            AdviceEditorSheet(hypothesis: hypothesis)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
    }

    private var draftHypotheses: [AdviceHypothesis] { drafts }

    // MARK: - Sections

    private func section(
        _ title: String,
        items: [AdviceHypothesis],
        empty: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Text("\(items.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            if items.isEmpty {
                Text(empty)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(items) { hypothesis in
                    card(hypothesis, tint: tint)
                }
            }
        }
    }

    // MARK: - Card

    private func card(_ hypothesis: AdviceHypothesis, tint: Color) -> some View {
        let progress = AdviceJournal.progress(for: hypothesis, trades: trades)
        let statusTint: Color = hypothesis.status == .confirmed
            ? Theme.green
            : (hypothesis.status == .rejected ? Theme.red : tint)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(hypothesis.status.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusTint.opacity(0.14)))

                Spacer(minLength: 4)

                Text(Fmt.shortDay(hypothesis.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text(hypothesis.title.isEmpty ? "Гипотеза не записана" : hypothesis.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(hypothesis.title.isEmpty ? Theme.orange : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !hypothesis.metric.isEmpty {
                Text("Метрика: \(hypothesis.metric)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Text("Сделок после: \(progress.tradesAfter)/\(AdviceJournal.checkAfterTrades(hypothesis))")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                if progress.isDue {
                    Text("Пора закрыть")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                } else {
                    Text("ещё \(progress.tradesLeft)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(progress.isDue ? Theme.orange : Theme.accent)
                        .frame(
                            width: max(
                                4,
                                proxy.size.width * CGFloat(
                                    min(
                                        Double(progress.tradesAfter) / Double(AdviceJournal.checkAfterTrades(hypothesis)),
                                        1
                                    )
                                )
                            )
                        )
                }
            }
            .frame(height: 6)

            HStack(spacing: 10) {
                valueTile("До", value: Fmt.r(progress.rBefore))
                valueTile("После", value: Fmt.r(progress.rAfter), tint: progress.rAfter >= progress.rBefore ? Theme.green : Theme.red)
            }

            actions(hypothesis)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private func valueTile(_ title: String, value: String, tint: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private func actions(_ hypothesis: AdviceHypothesis) -> some View {
        if hypothesis.status == .draft {
            Button {
                editing = hypothesis
                Haptics.tap()
            } label: {
                Text(hypothesis.isComplete ? "Проверять" : "Дополните измерение")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
        } else if hypothesis.status == .testing {
            HStack(spacing: 8) {
                Button {
                    close(hypothesis, status: .confirmed)
                } label: {
                    Text("Подтвердилось")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.green))
                }
                .buttonStyle(.plain)

                Button {
                    close(hypothesis, status: .rejected)
                } label: {
                    Text("Не подтвердилось")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func close(_ hypothesis: AdviceHypothesis, status: AdviceStatus) {
        hypothesis.status = status
        hypothesis.checkedAt = .now
        try? context.save()
        Haptics.success()
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
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
            SectionLabel(text: "Ассистент · гипотезы")
            ScreenTitle(text: "Советы")
            Text("Разбор ассистента становится гипотезой: что проверяем, чем измеряем и через сколько сделок закрываем.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dueCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell.badge")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.orange)
            Text("Пора закрыть: \(dueCount) \(dueCount == 1 ? "гипотеза" : "гипотез") набрали срок в сделках.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BreathingGlyph(systemName: "lightbulb")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            Text("Советов пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Сохраните разбор ассистента — он попадёт сюда черновиком. Запишите гипотезу, метрику и срок в сделках, и экран сам покажет, что было до и что стало после.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var emptyDraftHint: some View {
        Text("Черновиков нет: все сохранённые советы уже получили гипотезу и метрику.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 4)
    }
}

// MARK: - Editor

private struct AdviceEditorSheet: View {
    let hypothesis: AdviceHypothesis

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var metric = ""
    @State private var checkAfter = 5
    @State private var note = ""
    @State private var didLoad = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Гипотеза")
                            Text("Что проверяем")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer(minLength: 8)
                        Button("Закрыть") {
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }

                    GlassNoteField(
                        placeholder: "Гипотеза: что должно измениться",
                        text: $title,
                        limit: 300,
                        lines: 2...3,
                        minHeight: 52
                    )

                    GlassNoteField(
                        placeholder: "Метрика: что измеряем — R вне системы, winrate сессии, просадка",
                        text: $metric,
                        limit: 300,
                        lines: 2...3,
                        minHeight: 52
                    )

                    Stepper(value: $checkAfter, in: 1...50) {
                        Text("Срок проверки: \(checkAfter) сделок")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .tint(Theme.accent)

                    if !hypothesis.answer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Разбор ассистента")
                            Text(String(hypothesis.answer.prefix(700)))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 18)
                    }

                    PrimaryButton(title: "Начать проверку", isEnabled: canSave) {
                        save()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear(perform: load)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        title = hypothesis.title
        metric = hypothesis.metric
        checkAfter = max(hypothesis.checkAfterTrades, 1)
        note = hypothesis.note
    }

    private func save() {
        hypothesis.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        hypothesis.metric = metric.trimmingCharacters(in: .whitespacesAndNewlines)
        hypothesis.checkAfterTrades = max(checkAfter, 1)
        hypothesis.note = note
        hypothesis.status = .testing
        hypothesis.updatedAt = .now
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

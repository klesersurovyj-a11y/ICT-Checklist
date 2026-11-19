//
//  BankRatesLogView.swift
//  ICT Checklist
//
//  Журнал ставок и ожиданий трёх банков: ревизии не перезаписываются.
//

import SwiftUI
import SwiftData

private struct CurrencyTarget: Identifiable {
    let id: String
}

struct BankRatesLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \BankRateRevision.createdAt, order: .reverse)
    private var revisions: [BankRateRevision]

    @State private var editorTarget: CurrencyTarget?
    @State private var historyTarget: CurrencyTarget?

    private var currencies: [String] {
        CapitalFlows.allProfiles.map { $0.region.currency }
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

                    if revisions.isEmpty {
                        emptyCard
                            .reveal(.rise, 1)
                    } else {
                        ForEach(Array(currencies.enumerated()), id: \.element) { index, currency in
                            bankCard(currency)
                                .reveal(.rise, index + 1)
                        }
                        noteCard
                            .reveal(.rise, 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(item: $editorTarget) { target in
            BankRevisionEditor(currency: target.id, initial: latest(currency: target.id)) {
                editorTarget = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(item: $historyTarget) { target in
            RevisionHistorySheet(
                currency: currencyName(target.id),
                revisions: BankRatesLog.list(revisions, currency: target.id)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
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
            SectionLabel(text: "Банки · ревизии")
            ScreenTitle(text: "Ставки")
            Text("Журнал ревизий трёх банков: ставка, ожидания и сила валюты. История не перезаписывается.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cards

    private func bankCard(_ currency: String) -> some View {
        let latest = latest(currency: currency)
        let previous = BankRatesLog.previous(revisions, currency: currency)
        let changes = BankRatesLog.changes(latest: latest, previous: previous)
        let profile = CapitalFlows.allProfiles.first { $0.region.currency == currency }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(latest?.bank ?? profile?.policy.bank ?? currency)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(currency)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 4)

                if latest != nil {
                    Text(BankRatesLog.freshnessText(latest))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isStale(currency) ? Theme.orange : Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                (isStale(currency) ? Theme.orange : Theme.textTertiary).opacity(0.12)
                            )
                        )
                }
            }

            if let latest {
                Text(latest.rate.isEmpty ? "Ставка не записана" : latest.rate)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !latest.expectations.isEmpty || !latest.oneMonth.isEmpty {
                    Text(
                        "Ожидания: \(latest.expectations.isEmpty ? "—" : latest.expectations.lowercased()) · месяц \(latest.oneMonth.isEmpty ? "—" : latest.oneMonth) · квартал \(latest.quarter.isEmpty ? "—" : latest.quarter) · год \(latest.year.isEmpty ? "—" : latest.year)"
                    )
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !latest.bias.isEmpty {
                    Text("Сила валюты: \(latest.bias)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                if !changes.isEmpty {
                    Divider()
                        .overlay(Theme.hairline)

                    Text("С ПРОШЛОЙ РЕВИЗИИ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.textTertiary)

                    ForEach(changes) { change in
                        HStack(alignment: .top, spacing: 6) {
                            Text(change.title)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 105, alignment: .leading)
                            Text(change.from)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.top, 3)
                            Text(change.to)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !latest.source.isEmpty {
                    Text("Источник: \(latest.source)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !latest.note.isEmpty {
                    Text(latest.note)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Ревизий ещё нет — запишите первую.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 8) {
                Button {
                    editorTarget = CurrencyTarget(id: currency)
                    Haptics.tap()
                } label: {
                    Text(latest == nil ? "Записать ревизию" : "Новая ревизия")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)

                if !BankRatesLog.list(revisions, currency: currency).isEmpty {
                    Button {
                        historyTarget = CurrencyTarget(id: currency)
                        Haptics.tap()
                    } label: {
                        Text("История")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            BreathingGlyph(systemName: "percent")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)

            Text("Журнал пуст")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text("Зафиксируйте текущую аналитическую базу трёх банков — и дальше записывайте каждую ревизию. Старые записи останутся как есть.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Зафиксировать базу") {
                seedBase()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var noteCard: some View {
        InfoHint(
            text: "Ревизия старше 45 дней помечается на мировой карте: данные пора обновить. Новая запись сразу становится текущей ставкой банковского блока.",
            icon: "clock.arrow.circlepath"
        )
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Data

    private func latest(currency: String) -> BankRateRevision? {
        BankRatesLog.latest(revisions, currency: currency)
    }

    private func isStale(_ currency: String) -> Bool {
        BankRatesLog.isStale(latest(currency: currency))
    }

    private func currencyName(_ currency: String) -> String {
        CapitalFlows.allProfiles
            .first { $0.region.currency == currency }?
            .policy.bank ?? currency
    }

    private func seedBase() {
        for revision in BankRatesLog.baseRevisions() {
            context.insert(revision)
        }
        try? context.save()
        Haptics.success()
    }
}

// MARK: - Revision editor

private struct BankRevisionEditor: View {
    let currency: String
    let initial: BankRateRevision?
    var onClose: () -> Void

    @Environment(\.modelContext) private var context

    @State private var bank: String
    @State private var date: Date
    @State private var rate: String
    @State private var expectations: String
    @State private var oneMonth: String
    @State private var quarter: String
    @State private var year: String
    @State private var bias: String
    @State private var source: String
    @State private var note: String

    init(currency: String, initial: BankRateRevision?, onClose: @escaping () -> Void) {
        self.currency = currency
        self.initial = initial
        self.onClose = onClose

        let profile = CapitalFlows.allProfiles.first { $0.region.currency == currency }
        _bank = State(initialValue: initial?.bank ?? profile?.policy.bank ?? currency)
        _date = State(initialValue: .now)
        _rate = State(initialValue: initial?.rate ?? profile?.policy.metrics.policyRate ?? "")
        _expectations = State(initialValue: initial?.expectations ?? profile?.policy.expected.direction ?? "")
        _oneMonth = State(initialValue: initial?.oneMonth ?? profile?.policy.expected.oneMonth ?? "")
        _quarter = State(initialValue: initial?.quarter ?? profile?.policy.expected.quarter ?? "")
        _year = State(initialValue: initial?.year ?? profile?.policy.expected.year ?? "")
        _bias = State(initialValue: initial?.bias ?? profile?.policy.bias.label ?? "")
        _source = State(initialValue: "")
        _note = State(initialValue: "")
    }

    private var canSave: Bool {
        !rate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    GlassNoteField(
                        placeholder: "Ставка: 3,75–4,00% · ориентир",
                        text: $rate,
                        limit: 80,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Ожидания: пауза, смягчение, ужесточение",
                        text: $expectations,
                        limit: 120,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Через месяц",
                        text: $oneMonth,
                        limit: 120,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Через квартал",
                        text: $quarter,
                        limit: 120,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Через год",
                        text: $year,
                        limit: 120,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Сила валюты: сильная, нейтральная, слабая",
                        text: $bias,
                        limit: 80,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Источник: заседание, отчёт, комментарий",
                        text: $source,
                        limit: 200,
                        lines: 1...2,
                        minHeight: 44
                    )

                    GlassNoteField(
                        placeholder: "Почему изменилось: заметка к ревизии",
                        text: $note,
                        limit: 400,
                        lines: 2...4,
                        minHeight: 60
                    )

                    DatePicker("Дата ревизии", selection: $date, displayedComponents: .date)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .tint(Theme.accent)

                    PrimaryButton(title: "Сохранить ревизию", isEnabled: canSave) {
                        save()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Новая ревизия")
                Text(bank)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(currency)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            Button("Закрыть") {
                onClose()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
    }

    private func save() {
        let revision = BankRateRevision(
            createdAt: date,
            currency: currency,
            bank: bank,
            rate: rate.trimmingCharacters(in: .whitespacesAndNewlines),
            expectations: expectations.trimmingCharacters(in: .whitespacesAndNewlines),
            oneMonth: oneMonth.trimmingCharacters(in: .whitespacesAndNewlines),
            quarter: quarter.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year.trimmingCharacters(in: .whitespacesAndNewlines),
            bias: bias.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(revision)
        BankRatesLog.apply(revision)
        try? context.save()
        Haptics.success()
        onClose()
    }
}

// MARK: - History

private struct RevisionHistorySheet: View {
    let currency: String
    let revisions: [BankRateRevision]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("История ставок")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(currency)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                VStack(spacing: 0) {
                    ForEach(Array(revisions.enumerated()), id: \.element.persistentModelID) { index, revision in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(Fmt.shortDay(revision.createdAt))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(revision.rate)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer(minLength: 4)
                                Text(revision.bias)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .lineLimit(1)
                            }

                            let details = historyDetails(revision)
                            if !details.isEmpty {
                                Text(details)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !revision.source.isEmpty {
                                Text("Источник: \(revision.source)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)

                        if index < revisions.count - 1 {
                            Divider()
                                .overlay(Theme.hairline)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .glassCard(cornerRadius: 20)
            }
            .padding(22)
        }
    }

    private func historyDetails(_ revision: BankRateRevision) -> String {
        var parts: [String] = []
        if !revision.expectations.isEmpty {
            parts.append("ожидания \(revision.expectations.lowercased())")
        }
        if !revision.oneMonth.isEmpty {
            parts.append("месяц \(revision.oneMonth)")
        }
        if !revision.quarter.isEmpty {
            parts.append("квартал \(revision.quarter)")
        }
        if !revision.note.isEmpty {
            parts.append(revision.note)
        }
        return parts.joined(separator: " · ")
    }
}

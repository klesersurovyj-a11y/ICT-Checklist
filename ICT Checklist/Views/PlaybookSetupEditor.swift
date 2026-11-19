//
//  PlaybookSetupEditor.swift
//  ICT Checklist
//
//  Создание и редактирование сетапа плейбука.
//

import SwiftUI
import SwiftData

struct PlaybookSetupEditor: View {
    private let setup: PlaybookSetup
    private let isNew: Bool
    private let stats: PlaybookSetupStats?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var symbolsText: String
    @State private var direction: SetupDirection
    @State private var session: SetupSession
    @State private var marketState: String
    @State private var narrative: String
    @State private var pointA: String
    @State private var pointB: String
    @State private var zone: SetupZone
    @State private var delivery: String
    @State private var poi: SetupPOI
    @State private var confirmation: String
    @State private var riskMode: SetupRiskMode
    @State private var conditions: String
    @State private var rrText: String
    @State private var riskText: String
    @State private var checklistText: String
    @State private var note: String

    init(setup: PlaybookSetup, isNew: Bool, stats: PlaybookSetupStats? = nil) {
        self.setup = setup
        self.isNew = isNew
        self.stats = stats

        _name = State(initialValue: setup.name)
        _symbolsText = State(initialValue: setup.symbols.joined(separator: ", "))
        _direction = State(initialValue: setup.direction)
        _session = State(initialValue: setup.session)
        _marketState = State(initialValue: setup.marketState)
        _narrative = State(initialValue: setup.narrative)
        _pointA = State(initialValue: setup.pointA)
        _pointB = State(initialValue: setup.pointB)
        _zone = State(initialValue: setup.zone)
        _delivery = State(initialValue: setup.delivery)
        _poi = State(initialValue: setup.poi)
        _confirmation = State(initialValue: setup.confirmation)
        _riskMode = State(initialValue: setup.riskMode)
        _conditions = State(initialValue: setup.entryConditions)
        _rrText = State(initialValue: String(format: "%.1f", setup.typicalRR))
        _riskText = State(initialValue: String(format: "%.1f", setup.maxRiskPercent))
        _checklistText = State(initialValue: setup.checklistRaw)
        _note = State(initialValue: setup.note)
    }

    private var checklistCount: Int {
        checklistText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if let stats, stats.trades > 0 {
                        statsCard(stats)
                    }

                    thesisCard
                    marketCard
                    riskCard
                    checklistCard
                    noteCard

                    PrimaryButton(title: isNew ? "Создать сетап" : "Сохранить") {
                        save()
                    }

                    if !isNew {
                        SecondaryButton(title: setup.isArchived ? "Вернуть из архива" : "В архив") {
                            setup.isArchived.toggle()
                            try? context.save()
                            Haptics.tap()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: isNew ? "Плейбук · Новый сетап" : "Плейбук · Сетап")
                Text(isNew ? "Новый сетап" : setup.title)
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Text("Правила входа, шаги чек-листа и типовой RR — по ним считаются дисциплина и результат.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

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
        }
    }

    // MARK: - Stats

    private func statsCard(_ stats: PlaybookSetupStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Статистика сетапа")

            HStack(spacing: 0) {
                statCell("Сделки", "\(stats.trades)", tint: Theme.textPrimary, alignment: .leading)
                statCell("Win rate", "\(stats.winRate)%", tint: Theme.textPrimary, alignment: .center)
                statCell("Итог", Fmt.r(stats.totalR), tint: moneyTint(stats.totalR), alignment: .center)
                statCell("Средний R", Fmt.r(stats.averageR), tint: moneyTint(stats.averageR), alignment: .trailing)
            }

            HStack(spacing: 10) {
                Text("Дисциплина")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(stats.discipline >= 0.6 ? Theme.green : Theme.red)
                            .frame(width: max(6, proxy.size.width * min(max(stats.discipline, 0), 1)))
                    }
                }
                .frame(height: 6)

                Text("\(stats.disciplinePercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func statCell(_ title: String, _ value: String, tint: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : (alignment == .center ? .center : .leading))
    }

    private func moneyTint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textPrimary
    }

    // MARK: - Details

    private var thesisCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Тезис и маршрут")

            field("Название") {
                SingleLineField(placeholder: "Intraday · FVG Displacement", text: $name)
            }

            field("Направление") {
                GlassSegmented(
                    options: SetupDirection.allCases,
                    selection: $direction,
                    label: { $0.rawValue }
                )
            }

            field("Тип") {
                GlassSegmented(
                    options: SetupSession.allCases,
                    selection: $session,
                    label: { $0.rawValue }
                )
            }

            field("Состояние рынка") {
                SingleLineField(placeholder: "Тренд дня, диапазон, компрессия", text: $marketState)
            }

            field("Нарратив A→B") {
                GlassNoteField(
                    placeholder: "Что и куда доставляется: история сделки до входа",
                    text: $narrative,
                    limit: 600,
                    lines: 2...6
                )
            }

            field("Point A") {
                SingleLineField(placeholder: "Key Level или зона, откуда началось движение", text: $pointA)
            }

            field("Point B") {
                SingleLineField(placeholder: "Следующая цель по структуре", text: $pointB)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var marketCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Зона и доставка")

            field("Зона входа") {
                GlassSegmented(
                    options: SetupZone.allCases,
                    selection: $zone,
                    label: { $0.rawValue }
                )
            }

            field("POI") {
                GlassSegmented(
                    options: SetupPOI.allCases,
                    selection: $poi,
                    label: { $0.rawValue }
                )
            }

            field("Delivery") {
                SingleLineField(placeholder: "Strong flow, инвалидация потока", text: $delivery)
            }

            field("Подтверждение и индюсмент") {
                SingleLineField(placeholder: "Закрытие H1, IDM снят", text: $confirmation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Инструменты и риск")

            field("Инструменты") {
                SingleLineField(placeholder: "EURUSD, GBPUSD, XAUUSD", text: $symbolsText)
            }

            HStack(spacing: 10) {
                numberField("Типовой RR", text: $rrText, suffix: "R")
                numberField("Макс. риск", text: $riskText, suffix: "%")
            }

            field("Режим риска") {
                GlassSegmented(
                    options: SetupRiskMode.allCases,
                    selection: $riskMode,
                    label: { $0.rawValue }
                )
            }

            field("Вход") {
                GlassNoteField(
                    placeholder: "Как входим и что подтверждает вход",
                    text: $conditions,
                    limit: 600,
                    lines: 2...5
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Шаги чек-листа")
                Spacer(minLength: 0)
                Text("\(checklistCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }

            GlassNoteField(
                placeholder: "Каждый шаг с новой строки",
                text: $checklistText,
                limit: 800,
                lines: 4...14
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Заметка")
            GlassNoteField(placeholder: "Что важно помнить про этот сетап", text: $note, limit: 500, lines: 2...6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Fields

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private func numberField(_ title: String, text: Binding<String>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 6) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)

                Text(suffix)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
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
    }

    // MARK: - Save

    private func save() {
        setup.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.symbols = symbolsText
            .split(whereSeparator: { $0 == "," || $0 == "·" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        setup.direction = direction
        setup.session = session
        setup.marketState = marketState.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.narrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.pointA = pointA.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.pointB = pointB.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.zone = zone
        setup.delivery = delivery.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.poi = poi
        setup.confirmation = confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.riskMode = riskMode
        setup.entryConditions = conditions.trimmingCharacters(in: .whitespacesAndNewlines)
        setup.typicalRR = max(Double(rrText.replacingOccurrences(of: ",", with: ".")) ?? setup.typicalRR, 0.1)
        setup.maxRiskPercent = max(Double(riskText.replacingOccurrences(of: ",", with: ".")) ?? setup.maxRiskPercent, 0.1)
        setup.checklistRaw = checklistText
        setup.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if isNew {
            context.insert(setup)
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }
}

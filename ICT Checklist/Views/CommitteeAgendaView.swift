//
//  CommitteeAgendaView.swift
//  ICT Checklist
//
//  Повестка недельного заседания фонда: пункты из данных и протокол.
//

import SwiftUI
import SwiftData

struct CommitteeAgendaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \FundMandate.version, order: .reverse) private var mandates: [FundMandate]
    @Query(sort: \AdviceHypothesis.createdAt, order: .reverse)
    private var hypotheses: [AdviceHypothesis]
    @Query(sort: \BankRateRevision.createdAt, order: .reverse)
    private var revisions: [BankRateRevision]
    @Query(sort: \CommitteeProtocol.createdAt, order: .reverse)
    private var protocols: [CommitteeProtocol]

    @AppStorage("stress.lastRun") private var stressLastRun: Double = 0

    @State private var protocolNote = ""
    @State private var decisionItem: CommitteeItem?
    @State private var target: CommitteeTarget?
    @State private var showAssistant = false
    @State private var didLoadNote = false

    private var weekStartDate: Date {
        CommitteeAgenda.weekStart()
    }

    private var agenda: [CommitteeItem] {
        let stressDate = stressLastRun > 0
            ? Date(timeIntervalSince1970: stressLastRun)
            : nil
        return CommitteeAgenda.build(
            trades: trades,
            accounts: accounts,
            mandates: mandates,
            hypotheses: hypotheses,
            revisions: revisions,
            protocols: protocols,
            stressLastRun: stressDate
        )
    }

    private var decisionsNeeded: [CommitteeItem] {
        agenda.filter { $0.level == .decision }
    }

    private var watchItems: [CommitteeItem] {
        agenda.filter { $0.level == .watch }
    }

    private var currentProtocol: CommitteeProtocol? {
        protocols.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: weekStartDate) && !$0.isSigned
        }
    }

    private var lastSigned: CommitteeProtocol? {
        protocols.first { $0.isSigned }
    }

    private var signedThisWeek: CommitteeProtocol? {
        protocols.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: weekStartDate) && $0.isSigned
        }
    }

    private var decisions: [CommitteeDecision] {
        if let currentProtocol {
            return currentProtocol.decisions
        }
        return signedThisWeek?.decisions ?? []
    }

    private var canSign: Bool {
        !(currentProtocol?.decisions.isEmpty ?? true)
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

                    decisionsCard
                        .reveal(.zoom, 1)
                    watchCard
                        .reveal(.rise, 2)
                    protocolCard
                        .reveal(.rise, 3)
                    assistantButton
                        .reveal(.rise, 4)
                    pdfButton
                        .reveal(.rise, 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(item: $decisionItem) { item in
            CommitteeDecisionSheet(item: item) { decision in
                add(decision)
            } onOpenTarget: {
                if let target = item.target {
                    self.target = target
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $target) { target in
            switch target {
            case .compliance:
                ComplianceView()
            case .advice:
                AdviceJournalView()
            case .trades:
                TradesView()
            case .bankRates:
                BankRatesLogView()
            }
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: assistantPrompt)
        }
        .onAppear(perform: loadNote)
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
            SectionLabel(text: "Комитет · неделя \(CommitteeAgenda.weekLabel())")
            ScreenTitle(text: "Повестка")
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let version = mandates.first(where: { $0.isActive })?.version ?? 0
        let protocolText: String
        if let lastSigned, let signedAt = lastSigned.signedAt {
            protocolText = "протокол от \(Fmt.shortDay(signedAt))"
        } else {
            protocolText = "протокол не подписан"
        }
        return "\(agenda.count) \(pointWord(agenda.count)) · мандат v\(version) · \(protocolText)"
    }

    private func pointWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "пункт" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "пункта" }
        return "пунктов"
    }

    // MARK: - Cards

    private var decisionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Требует решения", count: decisionsNeeded.count)

            if decisionsNeeded.isEmpty {
                Text("Пунктов к решению нет: нарушения, гипотезы и разборы в порядке.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(decisionsNeeded.enumerated()), id: \.element.id) { index, item in
                    agendaRow(item, tint: item.id == "compliance" ? Theme.red : Theme.orange)
                    if index < decisionsNeeded.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Наблюдать", count: watchItems.count)

            if watchItems.isEmpty {
                Text("Наблюдать нечего: ревизии, стресс-тест и атрибуция свежие.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(watchItems.enumerated()), id: \.element.id) { index, item in
                    agendaRow(item, tint: Theme.textTertiary)
                    if index < watchItems.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func cardHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
        }
    }

    private func agendaRow(_ item: CommitteeItem, tint: Color) -> some View {
        Button {
            decisionItem = item
            Haptics.tap()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Protocol

    private var protocolCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Протокол", count: decisions.count)

            if decisions.isEmpty {
                Text("Решений пока нет. Откройте пункт повестки и запишите решение.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(decisions.enumerated()), id: \.element.id) { index, decision in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.green)

                        Text(decision.text)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Text(Fmt.shortDay(decision.createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 3)

                    if index < decisions.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }

            GlassNoteField(
                placeholder: "Заметка к протоколу",
                text: $protocolNote,
                limit: 400,
                lines: 1...3,
                minHeight: 46
            )

            Button {
                signProtocol()
            } label: {
                Text("Подписать протокол")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSign)
            .opacity(canSign ? 1 : 0.4)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var assistantButton: some View {
        Button {
            showAssistant = true
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lightbulb")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                Text("Черновик от ассистента")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var pdfButton: some View {
        Button {
            exportPDF()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Протокол в PDF")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var pdfData: CommitteeProtocolPDFData {
        let compliance = MandateCompliance.report(
            trades: trades,
            accounts: accounts,
            mandates: mandates
        )
        let violations = compliance.violations.prefix(12).map { violation in
            "\(Fmt.dayMonth(violation.date)) · \(violation.symbol) · \(violation.limit.rawValue): \(violation.detail) · \(Fmt.r(violation.r))"
        }

        let due = hypotheses.filter { hypothesis in
            hypothesis.status == .testing
                && AdviceJournal.progress(for: hypothesis, trades: trades).isDue
        }
        let hypothesisLines = due.map { hypothesis in
            let progress = AdviceJournal.progress(for: hypothesis, trades: trades)
            return "\(hypothesis.title.isEmpty ? "Без названия" : hypothesis.title) · \(hypothesis.metric) · \(progress.tradesAfter)/\(AdviceJournal.checkAfterTrades(hypothesis)) сделок"
        }

        let weekClosed = trades.filter { trade in
            guard trade.result != .open else { return false }
            let date = trade.closedAt ?? trade.entryDate
            return date >= weekStartDate
        }
        let weekR = weekClosed.reduce(0) { $0 + $1.actualR }

        return CommitteeProtocolPDFData(
            weekLabel: CommitteeAgenda.weekLabel(),
            mandateVersion: mandates.first(where: { $0.isActive })?.version ?? 0,
            weekR: weekR,
            items: agenda.map { ($0.title, $0.detail) },
            decisions: decisions,
            note: (currentProtocol ?? signedThisWeek)?.note ?? "",
            violations: Array(violations),
            hypotheses: hypothesisLines
        )
    }

    private func exportPDF() {
        guard let url = CommitteeProtocolPDF.make(pdfData) else {
            SharePresenter.presentFailure("Не удалось собрать протокол в PDF.")
            Haptics.warning()
            return
        }
        SharePresenter.share([url])
        Haptics.success()
    }

    // MARK: - Actions
    private var assistantPrompt: String {
        let points = agenda.map { "\($0.title) (\($0.detail))" }.joined(separator: "; ")
        return "Собери повестку комитета на неделю \(CommitteeAgenda.weekLabel()) и вопросы к заседанию. Пункты: \(points.isEmpty ? "пунктов нет" : points). По каждому пункту предложи решение — оставить, изменить или откатить — и что проверить после."
    }

    private func loadNote() {
        guard !didLoadNote else { return }
        didLoadNote = true
        protocolNote = (currentProtocol ?? signedThisWeek)?.note ?? ""
    }

    private func protocolForDecision() -> CommitteeProtocol {
        if let currentProtocol {
            return currentProtocol
        }
        let created = CommitteeProtocol(
            weekStart: weekStartDate,
            mandateVersion: mandates.first(where: { $0.isActive })?.version ?? 0
        )
        context.insert(created)
        return created
    }

    private func add(_ decision: CommitteeDecision) {
        let record = protocolForDecision()
        var list = record.decisions
        list.append(decision)
        record.decisions = list
        try? context.save()
        Haptics.success()
    }

    private func signProtocol() {
        let record = protocolForDecision()
        record.note = protocolNote.trimmingCharacters(in: .whitespacesAndNewlines)
        record.signedAt = .now
        try? context.save()
        Haptics.success()
    }
}

// MARK: - Decision sheet

private struct CommitteeDecisionSheet: View {
    let item: CommitteeItem
    var onAdd: (CommitteeDecision) -> Void
    var onOpenTarget: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var action: CommitteeAction = .keep
    @State private var text = ""
    @State private var note = ""
    @State private var didLoad = false

    private var canAdd: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Решение")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(item.title)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                if let target = item.target {
                    Button {
                        dismiss()
                        onOpenTarget()
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 6) {
                            Text(targetTitle(target))
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }

                GlassSegmented(
                    options: CommitteeAction.allCases,
                    selection: $action,
                    label: { $0.rawValue },
                    tint: { _ in Theme.accent }
                )

                GlassNoteField(
                    placeholder: "Решение",
                    text: $text,
                    limit: 300,
                    lines: 1...3,
                    minHeight: 48
                )

                GlassNoteField(
                    placeholder: "Заметка к решению",
                    text: $note,
                    limit: 300,
                    lines: 1...3,
                    minHeight: 48
                )

                PrimaryButton(title: "Добавить в протокол", isEnabled: canAdd) {
                    onAdd(
                        CommitteeDecision(
                            id: UUID().uuidString,
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            actionRaw: action.rawValue,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: .now
                        )
                    )
                    dismiss()
                }
                .padding(.top, 2)
            }
            .padding(22)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        text = "\(action.rawValue) \(item.subject)"
    }

    private func targetTitle(_ target: CommitteeTarget) -> String {
        switch target {
        case .compliance: return "Открыть комплаенс"
        case .advice: return "Открыть советы"
        case .trades: return "Открыть журнал"
        case .bankRates: return "Открыть ставки"
        }
    }
}

//
//  PlaybookView.swift
//  ICT Checklist
//
//  Плейбук сетапов фонда: правила, дисциплина и вклад в результат.
//

import SwiftUI
import SwiftData

struct PlaybookView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlaybookSetup.createdAt) private var setups: [PlaybookSetup]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: PlaybookPeriod = .days90
    @State private var scopeID: String?
    @State private var showArchived = false

    @State private var editorSetup: PlaybookSetup?
    @State private var editorIsNew = false
    @State private var tradeSetup: PlaybookSetup?

    private var activeAccounts: [TradingAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var scope: TradingAccount? {
        guard let scopeID else { return nil }
        return activeAccounts.first { "\($0.persistentModelID)" == scopeID }
    }

    private var activeSetups: [PlaybookSetup] {
        setups.filter { !$0.isArchived }
    }

    private var archivedSetups: [PlaybookSetup] {
        setups.filter(\.isArchived)
    }

    private var listedSetups: [PlaybookSetup] {
        showArchived ? activeSetups + archivedSetups : activeSetups
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)
                    periodRow
                        .reveal(.blur, 1)

                    if listedSetups.isEmpty {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        ForEach(Array(listedSetups.enumerated()), id: \.element.persistentModelID) { index, setup in
                            setupCard(setup)
                                .reveal(.rise, min(index + 2, 9))
                        }
                    }

                    if !archivedSetups.isEmpty {
                        archiveToggle
                            .reveal(.rise, 10)
                    }

                    actionRow
                        .reveal(.rise, 11)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(item: $editorSetup) { setup in
            PlaybookSetupEditor(
                setup: setup,
                isNew: editorIsNew,
                stats: editorIsNew
                    ? nil
                    : PlaybookEngine.stats(
                        for: setup,
                        trades: trades,
                        scope: scope,
                        period: period
                    )
            )
        }
        .fullScreenCover(item: $tradeSetup) { setup in
            NewTradeView(setup: setup)
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
            SectionLabel(text: "Фонд · Плейбук")
            ScreenTitle(text: "Плейбук")
            Text("Сетапы фонда: правила, дисциплина и вклад в результат.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Period

    private var periodBinding: Binding<PlaybookPeriod> {
        Binding(
            get: { period },
            set: { value in
                period = value
                Haptics.select()
            }
        )
    }

    private var periodRow: some View {
        HStack(spacing: 8) {
            GlassSegmented(
                options: PlaybookPeriod.allCases,
                selection: periodBinding,
                label: { $0.rawValue }
            )

            accountMenu
        }
    }

    private var accountMenu: some View {
        Menu {
            Button {
                scopeID = nil
                Haptics.select()
            } label: {
                if scopeID == nil {
                    Label("Все счета", systemImage: "checkmark")
                } else {
                    Text("Все счета")
                }
            }

            ForEach(activeAccounts) { account in
                let key = "\(account.persistentModelID)"
                let title = account.name.isEmpty ? account.type.rawValue : account.name
                Button {
                    scopeID = key
                    Haptics.select()
                } label: {
                    if scopeID == key {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(accountLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPanel(cornerRadius: 14)
        }
    }

    private var accountLabel: String {
        guard let scope else { return "Все счета" }
        return scope.name.isEmpty ? scope.type.rawValue : scope.name
    }

    // MARK: - Setup card

    private func setupCard(_ setup: PlaybookSetup) -> some View {
        let stats = PlaybookEngine.stats(
            for: setup,
            trades: trades,
            scope: scope,
            period: period
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(setup.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                directionBadge(setup.direction)

                Spacer(minLength: 0)

                setupMenu(setup)

                Button {
                    open(setup, isNew: false)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 32)
                }
                .buttonStyle(.plain)
            }

            Text(setup.symbolLine)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            if !setup.narrative.isEmpty {
                Text(setup.narrative)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let route = setup.routeLine {
                HStack(alignment: .top, spacing: 6) {
                    Text("A→B")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 1)

                    Text(route)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            HStack(spacing: 6) {
                miniBadge(setup.session.rawValue, tint: Theme.textSecondary)
                miniBadge(setup.zone.rawValue, tint: setup.zone == .discount ? Theme.green : (setup.zone == .premium ? Theme.red : Theme.textSecondary))
                miniBadge(setup.poi.rawValue, tint: Theme.textPrimary)
                Spacer(minLength: 0)
                Text(setup.riskMode.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            HStack(spacing: 0) {
                statColumn(value: "\(stats.trades)", label: Fmt.dealWord(stats.trades), tint: Theme.textPrimary, alignment: .leading)
                statColumn(value: "\(stats.winRate)%", label: "винрейт", tint: Theme.textPrimary, alignment: .leading)
                statColumn(value: Fmt.r(stats.totalR), label: "результат", tint: tint(stats.totalR), alignment: .trailing)
            }

            disciplineRow(stats)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
        .overlay(alignment: .topTrailing) {
            if setup.isArchived {
                Text("Архив")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
                    .padding(10)
            }
        }
        .opacity(setup.isArchived ? 0.6 : 1)
    }

    private func miniBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func directionBadge(_ direction: SetupDirection) -> some View {
        let color: Color = {
            switch direction {
            case .long: return Theme.green
            case .short: return Theme.red
            case .any: return Theme.textSecondary
            }
        }()

        return Text(direction.rawValue)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.16)))
    }

    private func setupMenu(_ setup: PlaybookSetup) -> some View {
        Menu {
            Button("Редактировать") {
                open(setup, isNew: false)
            }
            Button(setup.isArchived ? "Вернуть из архива" : "В архив") {
                setup.isArchived.toggle()
                try? setup.modelContext?.save()
                Haptics.tap()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, height: 32)
                .glassCircle()
        }
    }

    private func statColumn(value: String, label: String, tint: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    private func disciplineRow(_ stats: PlaybookSetupStats) -> some View {
        HStack(spacing: 10) {
            Text("Дисциплина")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

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

    private func tint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textPrimary
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                open(PlaybookSetup(), isNew: true)
            } label: {
                Text("Новый сетап")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(.plain)

            Menu {
                if activeSetups.isEmpty {
                    Text("Сначала создайте сетап")
                } else {
                    ForEach(activeSetups) { setup in
                        Button(setup.title) {
                            tradeSetup = setup
                            Haptics.tap()
                        }
                    }
                }
            } label: {
                Text("Сделка по сетапу")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassPanel(cornerRadius: 16)
            }
        }
    }

    private var archiveToggle: some View {
        Button {
            withAnimation(Theme.snappy) {
                showArchived.toggle()
            }
            Haptics.tap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                    .font(.system(size: 12, weight: .semibold))
                Text(showArchived ? "Скрыть архив" : "Показать архив · \(archivedSetups.count)")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func open(_ setup: PlaybookSetup, isNew: Bool) {
        editorIsNew = isNew
        editorSetup = setup
        Haptics.tap()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("В плейбуке пока пусто")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Создайте первый сетап: правила входа, шаги чек-листа и типовой RR. Сделки по сетапу будут копиться в его статистике.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }
}

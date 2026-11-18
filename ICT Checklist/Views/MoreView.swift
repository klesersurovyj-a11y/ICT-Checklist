//
//  MoreView.swift
//  ICT Checklist
//
//  «Все разделы»: единая структура приложения — риск, результаты,
//  разбор, система и сервис в одном месте.
//

import SwiftUI
import SwiftData

private enum MoreDestination: String, Identifiable {
    case riskLadder
    case riskIntelligence
    case monthlyReview
    case weeklyPerformance
    case marketBehavior
    case algorithmMonitor
    case report
    case achievements

    case secondBrain
    case journal
    case errors
    case goals

    case system
    case profiles
    case levels
    case accounts

    case assistant
    case settings

    var id: String { rawValue }
}

private struct MoreTile {
    let destination: MoreDestination
    let title: String
    let subtitle: String
    let icon: String
    var badge: String? = nil
}

private struct MoreGroup: Identifiable {
    let id: String
    let title: String
    let tiles: [MoreTile]
}

struct MoreView: View {
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Query private var errorNotes: [ErrorNote]
    @Query private var trades: [Trade]

    @State private var destination: MoreDestination?
    @State private var searchText = ""

    private var awaitingErrors: Int {
        errorNotes.filter { $0.status == .awaiting }.count
    }

    private var openTrades: Int {
        trades.filter { $0.result == .open }.count
    }

    private var groups: [MoreGroup] {
        [
            MoreGroup(
                id: "risk",
                title: "Риск",
                tiles: [
                    MoreTile(
                        destination: .riskLadder,
                        title: "Risk Ladder",
                        subtitle: "Ступени риска и путь капитала",
                        icon: "stairs"
                    ),
                    MoreTile(
                        destination: .riskIntelligence,
                        title: "Risk Intelligence",
                        subtitle: "Риск в R и %, просадка, лимиты",
                        icon: "shield.lefthalf.filled"
                    ),
                    MoreTile(
                        destination: .goals,
                        title: "Цели",
                        subtitle: "Месячная цель по R",
                        icon: "target"
                    )
                ]
            ),
            MoreGroup(
                id: "results",
                title: "Результаты",
                tiles: [
                    MoreTile(
                        destination: .monthlyReview,
                        title: "Monthly Review",
                        subtitle: "Разбор месяца в стиле THE EDGE",
                        icon: "calendar.badge.clock"
                    ),
                    MoreTile(
                        destination: .weeklyPerformance,
                        title: "Разбор недели",
                        subtitle: "Недельный результат и план",
                        icon: "chart.bar.doc.horizontal"
                    ),
                    MoreTile(
                        destination: .marketBehavior,
                        title: "Market Behavior",
                        subtitle: "Структура, сессии, дни, POI",
                        icon: "waveform.path.ecg"
                    ),
                    MoreTile(
                        destination: .algorithmMonitor,
                        title: "Algorithm Monitor",
                        subtitle: "Скользящие метрики и сигнал",
                        icon: "chart.line.uptrend.xyaxis"
                    ),
                    MoreTile(
                        destination: .report,
                        title: "Отчёты PDF",
                        subtitle: "Итоги за период",
                        icon: "doc.text"
                    ),
                    MoreTile(
                        destination: .achievements,
                        title: "Достижения",
                        subtitle: "Вехи и прогресс",
                        icon: "trophy"
                    )
                ]
            ),
            MoreGroup(
                id: "review",
                title: "Разбор и знания",
                tiles: [
                    MoreTile(
                        destination: .secondBrain,
                        title: "Second Brain",
                        subtitle: "Наблюдения, гипотезы, правила",
                        icon: "brain.head.profile"
                    ),
                    MoreTile(
                        destination: .journal,
                        title: "Дневник",
                        subtitle: "Состояние и выводы дня",
                        icon: "book.closed"
                    ),
                    MoreTile(
                        destination: .errors,
                        title: "Ошибки",
                        subtitle: awaitingErrors > 0
                            ? "Ждут разбора: \(awaitingErrors)"
                            : "Что нарушило систему",
                        icon: "exclamationmark.bubble",
                        badge: awaitingErrors > 0 ? "\(awaitingErrors)" : nil
                    )
                ]
            ),
            MoreGroup(
                id: "system",
                title: "Система",
                tiles: [
                    MoreTile(
                        destination: .system,
                        title: "Конструктор",
                        subtitle: "TDA + Risk: этапы и риск",
                        icon: "square.grid.2x2"
                    ),
                    MoreTile(
                        destination: .profiles,
                        title: "Профили",
                        subtitle: "Системы трейдеров и риск",
                        icon: "person.2"
                    ),
                    MoreTile(
                        destination: .levels,
                        title: "Key Levels",
                        subtitle: "Рабочие уровни дня",
                        icon: "square.stack.3d.up"
                    ),
                    MoreTile(
                        destination: .accounts,
                        title: "Счета",
                        subtitle: openTrades > 0
                            ? "Открытых сделок: \(openTrades)"
                            : "Баланс, операции, выплаты",
                        icon: "creditcard"
                    )
                ]
            ),
            MoreGroup(
                id: "service",
                title: "Сервис",
                tiles: [
                    MoreTile(
                        destination: .assistant,
                        title: "ИИ-ассистент",
                        subtitle: "Разбор сделок и системы",
                        icon: "sparkles"
                    ),
                    MoreTile(
                        destination: .settings,
                        title: "Настройки",
                        subtitle: "Риск, лимиты, данные, ключи",
                        icon: "gearshape"
                    )
                ]
            )
        ]
    }

    private var filteredGroups: [MoreGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let tiles = group.tiles.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query)
            }
            return tiles.isEmpty ? nil : MoreGroup(id: group.id, title: group.title, tiles: tiles)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchRow

                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: group.title)
                            groupGrid(group)
                        }
                    }

                    if filteredGroups.isEmpty {
                        emptySearch
                    }

                    Text("Все разделы живут в одной базе и синхронизируются через iCloud.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(item: $destination) { destination in
            destinationView(destination)
        }
    }

    @ViewBuilder
    private func groupGrid(_ group: MoreGroup) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                groupTiles(group)
            }
        } else {
            groupTiles(group)
        }
    }

    private func groupTiles(_ group: MoreGroup) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(group.tiles, id: \.destination.rawValue) { tile in
                SectionTile(
                    title: tile.title,
                    subtitle: tile.subtitle,
                    icon: tile.icon,
                    badge: tile.badge
                ) {
                    destination = tile.destination
                    Haptics.tap()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Структура приложения")
                ScreenTitle(text: "Все разделы")
                Text("Риск, результаты, разбор, система и сервис — сгруппированы по смыслу.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if isModal {
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
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Найти раздел", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .tint(Theme.accent)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var emptySearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Раздел не найден")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Попробуйте другое слово — например «риск», «отчёт» или «дневник».")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destinationView(_ destination: MoreDestination) -> some View {
        switch destination {
        case .riskLadder:
            RiskLadderView()
        case .riskIntelligence:
            RiskIntelligenceView()
        case .monthlyReview:
            MonthlyPerformanceView()
        case .weeklyPerformance:
            WeeklyPerformanceView()
        case .marketBehavior:
            MarketBehaviorView()
        case .algorithmMonitor:
            AlgorithmMonitorView()
        case .report:
            ReportView()
        case .achievements:
            AchievementsView()
        case .secondBrain:
            SecondBrainView()
        case .journal:
            JournalView()
        case .errors:
            ErrorsView()
        case .goals:
            GoalView()
        case .system:
            SystemView()
        case .profiles:
            ProfilesView()
        case .levels:
            LevelsView()
        case .accounts:
            AccountsView()
        case .assistant:
            AssistantView()
        case .settings:
            SettingsView()
        }
    }
}

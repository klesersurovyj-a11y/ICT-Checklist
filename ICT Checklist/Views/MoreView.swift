//
//  MoreView.swift
//  ICT Checklist
//
//  «Все разделы»: компактный каталог приложения в четырёх группах.
//

import SwiftUI
import SwiftData

private enum MoreDestination: String, Identifiable {
    case search
    case terminal
    case charts
    case worldEconomy
    case bankRates
    case portfolio
    case equityCurve
    case capitalDiscipline
    case compliance
    case committeeAgenda
    case systemVersions
    case setupWeights
    case disciplineSystem
    case correlations
    case monteCarlo
    case riskLadder
    case riskIntelligence
    case calculator
    case monthlyReview
    case weeklyPerformance
    case calendar
    case marketBehavior
    case algorithmMonitor
    case entryHours
    case tags
    case benchmark
    case tradeDuration
    case report
    case achievements

    case secondBrain
    case adviceJournal
    case playbook
    case training
    case journal
    case errors
    case goals

    case system
    case profiles
    case levels
    case accounts
    case csvImport

    case assistant
    case settings

    var id: String { rawValue }
}

private struct MoreSection: Identifiable {
    let destination: MoreDestination
    let title: String
    let icon: String
    var badge: String? = nil

    var id: String { destination.rawValue }
}

private struct MoreGroup: Identifiable {
    let id: String
    let title: String
    let sections: [MoreSection]
}

struct MoreView: View {
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Query private var errorNotes: [ErrorNote]
    @Query private var trades: [Trade]

    @State private var destination: MoreDestination?

    private var awaitingErrors: Int {
        errorNotes.filter { $0.status == .awaiting }.count
    }

    private var openTrades: Int {
        trades.filter { $0.result == .open }.count
    }

    private var groups: [MoreGroup] {
        [
            MoreGroup(
                id: "capital",
                title: "Капитал и риск",
                sections: [
                    MoreSection(destination: .portfolio, title: "Портфель", icon: "briefcase"),
                    MoreSection(destination: .equityCurve, title: "Капитал и просадка", icon: "chart.xyaxis.line"),
                    MoreSection(destination: .capitalDiscipline, title: "Цена своеволия", icon: "scale.3d"),
                    MoreSection(destination: .compliance, title: "Комплаенс", icon: "shield.checkered"),
                    MoreSection(destination: .committeeAgenda, title: "Повестка комитета", icon: "list.clipboard"),
                    MoreSection(destination: .systemVersions, title: "Версии системы", icon: "clock.arrow.circlepath"),
                    MoreSection(destination: .setupWeights, title: "Веса сетапов", icon: "chart.pie"),
                    MoreSection(destination: .disciplineSystem, title: "Дисциплина", icon: "checkmark.seal"),
                    MoreSection(destination: .correlations, title: "Корреляции", icon: "tablecells"),
                    MoreSection(destination: .monteCarlo, title: "Монте-Карло", icon: "chart.bar.xaxis"),
                    MoreSection(destination: .riskLadder, title: "Risk Ladder", icon: "stairs"),
                    MoreSection(destination: .riskIntelligence, title: "Risk Intelligence", icon: "shield.lefthalf.filled"),
                    MoreSection(destination: .calculator, title: "Калькулятор позиции", icon: "percent"),
                    MoreSection(destination: .goals, title: "Цели", icon: "target")
                ]
            ),
            MoreGroup(
                id: "results",
                title: "Результаты",
                sections: [
                    MoreSection(destination: .monthlyReview, title: "Monthly Review", icon: "calendar.badge.clock"),
                    MoreSection(destination: .weeklyPerformance, title: "Разбор недели", icon: "chart.bar.doc.horizontal"),
                    MoreSection(destination: .calendar, title: "Календарь", icon: "calendar"),
                    MoreSection(destination: .marketBehavior, title: "Market Behavior", icon: "waveform.path.ecg"),
                    MoreSection(destination: .algorithmMonitor, title: "Algorithm Monitor", icon: "chart.line.uptrend.xyaxis"),
                    MoreSection(destination: .entryHours, title: "Часы входа", icon: "square.grid.3x3"),
                    MoreSection(destination: .tags, title: "Теги", icon: "tag"),
                    MoreSection(destination: .benchmark, title: "Бенчмарк", icon: "chart.xyaxis.line"),
                    MoreSection(destination: .tradeDuration, title: "Время в сделке", icon: "hourglass"),
                    MoreSection(destination: .report, title: "Отчёты PDF", icon: "doc.text"),
                    MoreSection(destination: .achievements, title: "Достижения", icon: "trophy")
                ]
            ),
            MoreGroup(
                id: "review",
                title: "Разбор и знания",
                sections: [
                    MoreSection(destination: .secondBrain, title: "Second Brain", icon: "brain.head.profile"),
                    MoreSection(destination: .adviceJournal, title: "Советы", icon: "lightbulb"),
                    MoreSection(destination: .playbook, title: "Плейбук", icon: "rectangle.stack"),
                    MoreSection(destination: .training, title: "Тренировка входа", icon: "target"),
                    MoreSection(destination: .journal, title: "Дневник", icon: "book.closed"),
                    MoreSection(
                        destination: .errors,
                        title: "Ошибки",
                        icon: "exclamationmark.bubble",
                        badge: awaitingErrors > 0 ? "\(awaitingErrors)" : nil
                    )
                ]
            ),
            MoreGroup(
                id: "tools",
                title: "Инструменты и данные",
                sections: [
                    MoreSection(destination: .terminal, title: "Терминал", icon: "chart.bar.xaxis"),
                    MoreSection(destination: .charts, title: "Графики TradingView", icon: "chart.xyaxis.line"),
                    MoreSection(destination: .worldEconomy, title: "Мировая экономика", icon: "globe.europe.africa"),
                    MoreSection(destination: .bankRates, title: "Ставки банков", icon: "banknote"),
                    MoreSection(destination: .system, title: "Конструктор", icon: "square.grid.2x2"),
                    MoreSection(destination: .profiles, title: "Профили", icon: "person.2"),
                    MoreSection(destination: .levels, title: "Key Levels", icon: "square.stack.3d.up"),
                    MoreSection(
                        destination: .accounts,
                        title: "Счета",
                        icon: "creditcard",
                        badge: openTrades > 0 ? "\(openTrades)" : nil
                    ),
                    MoreSection(destination: .csvImport, title: "Импорт из CSV", icon: "square.and.arrow.down"),
                    MoreSection(destination: .assistant, title: "ИИ-ассистент", icon: "sparkles"),
                    MoreSection(destination: .settings, title: "Настройки", icon: "gearshape")
                ]
            )
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchRow

                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                SectionLabel(text: group.title)
                                Spacer(minLength: 0)
                                Text("\(group.sections.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            groupCard(group)
                        }
                    }
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Структура приложения")
                ScreenTitle(text: "Все разделы")
                Text("Всё приложение в четырёх группах — от капитала до данных.")
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
        Button {
            open(.search)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, alignment: .leading)

                Text("Поиск по всей базе")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 16, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func groupCard(_ group: MoreGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.leading, 48)
                }

                row(section, index: index)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    private func row(_ section: MoreSection, index: Int) -> some View {
        Button {
            open(section.destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, alignment: .leading)
                    .iconPop(delay: 0.2 + Double(min(index, 9)) * 0.05)

                Text(section.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .pieceIn(delay: 0.45 + Double(min(index, 9)) * 0.06)

                Spacer(minLength: 6)

                if let badge = section.badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func open(_ destination: MoreDestination) {
        self.destination = destination
        Haptics.tap()
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destinationView(_ destination: MoreDestination) -> some View {
        switch destination {
        case .search:
            SearchView()
        case .terminal:
            TerminalView()
        case .charts:
            TradingChartsView()
        case .worldEconomy:
            WorldEconomyView()
        case .bankRates:
            BankRatesLogView()
        case .portfolio:
            PortfolioView()
        case .equityCurve:
            EquityCurveView()
        case .capitalDiscipline:
            CapitalDisciplineView()
        case .compliance:
            ComplianceView()
        case .committeeAgenda:
            CommitteeAgendaView()
        case .systemVersions:
            SystemVersionsView()
        case .setupWeights:
            SetupWeightsView()
        case .disciplineSystem:
            DisciplineSystemView()
        case .correlations:
            CorrelationView()
        case .monteCarlo:
            MonteCarloView()
        case .riskLadder:
            RiskLadderView()
        case .riskIntelligence:
            RiskIntelligenceView()
        case .calculator:
            PositionCalculatorView()
        case .monthlyReview:
            MonthlyPerformanceView()
        case .weeklyPerformance:
            WeeklyPerformanceView()
        case .calendar:
            CalendarView()
        case .marketBehavior:
            MarketBehaviorView()
        case .algorithmMonitor:
            AlgorithmMonitorView()
        case .entryHours:
            EntryHoursView()
        case .tags:
            TagStatsView()
        case .benchmark:
            BenchmarkView()
        case .tradeDuration:
            TradeDurationView()
        case .report:
            ReportView()
        case .achievements:
            AchievementsView()
        case .secondBrain:
            SecondBrainView()
        case .adviceJournal:
            AdviceJournalView()
        case .playbook:
            PlaybookView()
        case .training:
            EntryTrainingView()
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
        case .csvImport:
            CSVImportView()
        case .assistant:
            AssistantView()
        case .settings:
            SettingsView()
        }
    }
}

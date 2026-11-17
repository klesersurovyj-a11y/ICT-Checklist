//
//  StatisticsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var trades: [Trade]
    @Query private var settingsList: [AppSettings]
    @Query private var plans: [TradePlan]
    @Query private var errorNotes: [ErrorNote]
    @Query private var accounts: [TradingAccount]

    @State private var period: StatsPeriod = .all
    @State private var breakdownTarget: BreakdownTarget?
    @State private var showReport = false
    @State private var showGoal = false
    @State private var showLossReview = false
    @State private var showErrors = false
    @State private var showJournal = false
    @State private var showCompare = false
    @State private var showWeeklyPerformance = false
    @State private var showAchievements = false

    private var settings: AppSettings? { settingsList.first }
    private var amounts: [Double] {
        let list = settings?.ladderAmounts ?? []
        return list.count == 3 ? list : [12, 25, 50]
    }

    private var summary: StatsSummary {
        StatsEngine.summary(trades: trades, amounts: amounts, period: period)
    }

    private var planStats: StatsEngine.PlanStats {
        StatsEngine.planStats(plans: plans, period: period)
    }

    private var charts: ChartSeries {
        StatsEngine.charts(trades: trades, period: period)
    }

    private var accountGroups: [StatsGroup] {
        StatsEngine.accountGroups(trades: trades, accounts: accounts, period: period)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .reveal(.slideRight)

                    GlassSegmented(
                        options: StatsPeriod.allCases,
                        selection: $period,
                        label: { $0.rawValue },
                        tint: { _ in Theme.blue }
                    )

                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .reveal(.blur, 1)

                    if summary.closedCount == 0 {
                        emptyCard
                    } else {
                        tilesGrid
                            .reveal(.zoom, 2)
                        equityCard
                        streakCard
                            .reveal(.rise, 4)
                        chartsSection
                            .reveal(.rise, 5)
                        weeksCard
                            .reveal(.rise, 6)
                        breakdownSection("По символам", summary.bySymbol) { group in
                            .symbol(group.title)
                        }
                        breakdownSection("По направлениям", summary.byDirection) { group in
                            .direction(Direction(rawValue: group.title) ?? .long)
                        }
                        breakdownSection("По ступеням риска", summary.byStep) { group in
                            .step(summary.byStep.firstIndex(where: { $0.id == group.id }) ?? 0)
                        }
                        if !accountGroups.isEmpty {
                            breakdownSection("По счетам", accountGroups) { group in
                                group.kind ?? .noAccount
                            }
                        }
                        breakdownSection(
                            "По дням недели",
                            summary.byWeekday,
                            kindFor: { group in
                                .weekday(weekdayIndex(of: group))
                            },
                            detailTitleFor: { group in
                                StatsEngine.weekdayNames[weekdayIndex(of: group)]
                            }
                        )
                        breakdownSection("По времени входа", summary.byHour) { group in
                            .hour(entryHour(of: group))
                        }
                        if !summary.byTag.isEmpty {
                            breakdownSection("По меткам", summary.byTag) { group in
                                .tag(group.title)
                            }
                        }
                    }

                    plansCard
                        .reveal(.rise, 7)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(Theme.snappy, value: period)
            }
        }
        .fullScreenCover(item: $breakdownTarget) { target in
            BreakdownDetailView(target: target, period: $period)
        }
        .fullScreenCover(isPresented: $showReport) {
            ReportView()
        }
        .fullScreenCover(isPresented: $showGoal) {
            GoalView()
        }
        .fullScreenCover(isPresented: $showLossReview) {
            LossReviewView()
        }
        .fullScreenCover(isPresented: $showErrors) {
            ErrorsView()
        }
        .fullScreenCover(isPresented: $showJournal) {
            JournalView()
        }
        .fullScreenCover(isPresented: $showCompare) {
            CompareTradesView()
        }
        .fullScreenCover(isPresented: $showWeeklyPerformance) {
            WeeklyPerformanceView()
        }
        .fullScreenCover(isPresented: $showAchievements) {
            AchievementsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Результат")
                ScreenTitle(text: "Статистика")
            }
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                Button {
                    showAchievements = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "trophy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showLossReview = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.down.right.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showErrors = true
                    Haptics.tap()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

                        if awaitingErrors > 0 {
                            Text("\(awaitingErrors)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 15, height: 15)
                                .background(Circle().fill(Theme.orange))
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showJournal = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "book.closed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showCompare = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showGoal = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showReport = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var awaitingErrors: Int {
        errorNotes.filter { $0.status == .awaiting }.count
    }

    private var caption: String {
        "\(Fmt.deals(summary.totalCount)) · \(summary.closedCount) закрыто"
    }

    // MARK: - Tiles

    private var tilesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            StatTile(
                title: "Win rate",
                value: "\(Int((summary.winRate * 100).rounded()))%",
                subtitle: "\(summary.wins) из \(summary.closedCount)",
                tint: Theme.green
            )
            StatTile(
                title: "Суммарный R",
                value: Fmt.signed(summary.totalR, digits: 1),
                subtitle: Fmt.deals(summary.closedCount),
                tint: rColor(summary.totalR)
            )
            StatTile(
                title: "Средний R",
                value: Fmt.signed(summary.averageR, digits: 2),
                subtitle: "на сделку",
                tint: .white
            )
            StatTile(
                title: "Profit factor",
                value: profitFactorText,
                subtitle: "плюсы / минусы",
                tint: Theme.blue
            )
        }
    }

    private var profitFactorText: String {
        guard let pf = summary.profitFactor else {
            return summary.wins > 0 ? "∞" : "—"
        }
        return String(format: "%.1f", pf)
    }

    // MARK: - Equity curve

    private struct EquityPoint: Identifiable {
        let id: Int
        let date: Date
        let value: Double
    }

    private var equityPoints: [EquityPoint] {
        let calendar = Calendar.current
        let closed = trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.tradingDay) }
            .sorted { ($0.closedAt ?? $0.tradingDay) < ($1.closedAt ?? $1.tradingDay) }

        guard let first = closed.first else { return [] }

        var running = 0.0
        var points: [EquityPoint] = [
            EquityPoint(
                id: 0,
                date: calendar.startOfDay(for: first.closedAt ?? first.tradingDay),
                value: 0
            )
        ]

        for (offset, trade) in closed.enumerated() {
            running += trade.actualR * trade.riskUSD
            points.append(
                EquityPoint(
                    id: offset + 1,
                    date: trade.closedAt ?? trade.tradingDay,
                    value: running
                )
            )
        }
        return points
    }

    private var equityFinal: Double {
        equityPoints.last?.value ?? 0
    }

    private var equityTotalR: Double {
        trades
            .filter { $0.result != .open }
            .filter { period.contains($0.closedAt ?? $0.tradingDay) }
            .reduce(0) { $0 + $1.actualR }
    }

    private var equityText: String {
        let sign: String
        if equityFinal > 0.005 {
            sign = "+"
        } else if equityFinal < -0.005 {
            sign = "\u{2212}"
        } else {
            sign = ""
        }
        return sign + Fmt.money(abs(equityFinal))
    }

    private var equityCard: some View {
        let points = equityPoints
        let values = points.map(\.value)
        let minValue = min(0, values.min() ?? 0)
        let maxValue = max(0, values.max() ?? 0)
        let span = max(maxValue - minValue, 1)
        let lower = minValue - span * 0.18
        let upper = maxValue + span * 0.18

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Equity curve")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Fmt.signed(equityTotalR, digits: 1))R · капитал по закрытым сделкам")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 6)
                Text(equityText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        equityFinal > 0.005 ? Theme.green : (equityFinal < -0.005 ? Theme.red : .white)
                    )
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Chart {
                RuleMark(y: .value("Ноль", 0))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(points) { point in
                    AreaMark(
                        x: .value("Сделка", point.id),
                        yStart: .value("Ноль", 0),
                        yEnd: .value("Капитал", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Сделка", point.id),
                        y: .value("Капитал", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                if let last = points.last {
                    PointMark(
                        x: .value("Сделка", last.id),
                        y: .value("Капитал", last.value)
                    )
                    .foregroundStyle(equityFinal >= 0 ? Theme.green : Theme.red)
                    .symbolSize(46)
                }
            }
            .chartYScale(domain: lower...upper)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(shortMoney(v))
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 142)
            .animation(.easeInOut(duration: 0.55), value: points.count)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
        .cardEntrance()
    }

    private func shortMoney(_ value: Double) -> String {
        let magnitude = abs(value)
        let text = magnitude >= 1000
            ? String(format: "%.1fk", magnitude / 1000)
            : String(format: "%.0f", magnitude)
        return (value < 0 ? "\u{2212}" : "") + "$" + text
    }

    // MARK: - Weeks heat map

    private struct WeekCell: Identifiable {
        let id: Date
        let start: Date
        let totalR: Double
        let trades: Int
    }

    private var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekCells: [WeekCell] {
        let calendar = weekCalendar
        let today = calendar.startOfDay(for: .now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

        let closed = trades.filter { $0.result != .open }

        return (0..<12).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: thisWeek),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else {
                return nil
            }

            let items = closed.filter { trade in
                let day = calendar.startOfDay(for: trade.tradingDay)
                return day >= start && day < end
            }

            return WeekCell(
                id: start,
                start: start,
                totalR: items.reduce(0) { $0 + $1.actualR },
                trades: items.count
            )
        }
    }

    private var weeksCard: some View {
        let cells = weekCells
        let filled = cells.filter { $0.trades > 0 }
        let best = filled.max { $0.totalR < $1.totalR }
        let worst = filled.min { $0.totalR < $1.totalR }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "По неделям")
                Spacer(minLength: 8)
                Text("12 недель")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                ForEach(cells) { cell in
                    Button {
                        openWeek(cell.start)
                    } label: {
                        weekSquare(cell)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            if let best, let worst {
                Text("Лучшая неделя \(Fmt.r(best.totalR)) · худшая \(Fmt.r(worst.totalR))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Пока нет закрытых сделок за 12 недель")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            Divider()
                .overlay(Theme.hairline)

            Button {
                showWeeklyPerformance = true
                Haptics.tap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Разбор недели")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func weekSquare(_ cell: WeekCell) -> some View {
        let tint = weekTint(cell)

        return VStack(spacing: 3) {
            Text(Self.weekLabelFormatter.string(from: cell.start))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)

            Text(cell.trades == 0 ? "—" : Fmt.r(cell.totalR))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(weekFill(cell))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(cell.trades == 0 ? 0.08 : 0.45), lineWidth: 0.8)
        )
    }

    private func weekTint(_ cell: WeekCell) -> Color {
        guard cell.trades > 0 else { return Theme.textTertiary }
        if cell.totalR > 0.05 { return Theme.green }
        if cell.totalR < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private func weekFill(_ cell: WeekCell) -> Color {
        guard cell.trades > 0 else { return Color.white.opacity(0.03) }
        if cell.totalR > 0.05 { return Theme.green.opacity(0.16) }
        if cell.totalR < -0.05 { return Theme.red.opacity(0.16) }
        return Color.white.opacity(0.05)
    }

    private func openWeek(_ start: Date) {
        let calendar = weekCalendar
        let monday = calendar.startOfDay(for: start)
        guard let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return }
        let title = "Неделя \(Fmt.dayMonth(monday)) – \(Fmt.dayMonth(sunday))"
        breakdownTarget = BreakdownTarget(
            id: "week-\(monday.timeIntervalSince1970)",
            title: title,
            kind: .week(monday)
        )
        Haptics.tap()
    }

    private static let weekLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    // MARK: - Streaks

    private var streakCard: some View {
        HStack(spacing: 0) {
            streakColumn(
                title: "Лучшая серия",
                streak: summary.bestStreak,
                tint: Theme.green,
                sign: "+"
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 40)
                .overlay(Color.white.opacity(0.08))

            streakColumn(
                title: "Худшая серия",
                streak: summary.worstStreak,
                tint: Theme.red,
                sign: "\u{2212}"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 22)
    }

    private func streakColumn(title: String, streak: StatsStreak, tint: Color, sign: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            if streak.count == 0 {
                Text("—")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text("\(sign)\(streak.count) \(Fmt.dealWord(streak.count)) / \(Fmt.r(streak.totalR))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Breakdowns

    private func breakdownSection(
        _ title: String,
        _ groups: [StatsGroup],
        kindFor: @escaping (StatsGroup) -> BreakdownKind,
        detailTitleFor: ((StatsGroup) -> String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.leading, 16)
                    }
                    breakdownRow(
                        group,
                        kind: kindFor(group),
                        detailTitle: detailTitleFor?(group) ?? group.title
                    )
                }
            }
            .glassCard(cornerRadius: 22)
        }
    }

    private func breakdownRow(_ group: StatsGroup, kind: BreakdownKind, detailTitle: String) -> some View {
        Button {
            breakdownTarget = BreakdownTarget(
                id: group.id,
                title: detailTitle,
                kind: kind
            )
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(Fmt.deals(group.count))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(Int((group.winRate * 100).rounded()))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .frame(minWidth: 36, alignment: .trailing)

                Text(Fmt.r(group.totalR))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rColor(group.totalR))
                    .frame(minWidth: 52, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                MiniBar(wins: group.wins, losses: group.losses, total: group.count)
                    .frame(width: 82, height: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нет закрытых сделок")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var emptyMessage: String {
        if period != .all && trades.contains(where: { $0.result != .open }) {
            return "В этом периоде закрытых сделок нет. Переключите период или закройте позицию по TP, SL или BE."
        }
        return "Закройте позицию по TP, SL или BE в «Сделках» — здесь появятся накопленный R и риск по ступеням."
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private func weekdayIndex(of group: StatsGroup) -> Int {
        summary.byWeekday.firstIndex(where: { $0.id == group.id }) ?? 0
    }

    private func entryHour(of group: StatsGroup) -> Int {
        Int(group.title.prefix(2)) ?? 0
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansCard: some View {
        let stats = planStats

        if stats.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Планы")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    StatTile(
                        title: "Отработка планов",
                        value: percentText(stats.executionRate),
                        subtitle: "вход из \(stats.withResult) решений",
                        tint: Theme.accent
                    )
                    StatTile(
                        title: "Соблюдение системы",
                        value: percentText(stats.complianceRate),
                        subtitle: "чек-лист 100%",
                        tint: Theme.green
                    )
                }

                Text(countsLine(stats))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(cornerRadius: 26)
        }
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func countsLine(_ stats: StatsEngine.PlanStats) -> String {
        var parts = ["Планов \(stats.total)"]
        if stats.decided > 0 { parts.append("Win / Loss / BE \(stats.decided)") }
        if stats.skipped > 0 { parts.append("Skip \(stats.skipped)") }
        if stats.noTrade > 0 { parts.append("No trade \(stats.noTrade)") }
        if stats.pending > 0 { parts.append("Без итога \(stats.pending)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            accumulatedRCard
            riskStepsCard
        }
    }

    private var accumulatedRCard: some View {
        let series = charts
        let values = series.rPoints.map(\.value)
        let minValue = min(0, values.min() ?? 0)
        let maxValue = max(0, values.max() ?? 0)
        let span = max(maxValue - minValue, 1)
        let lower = minValue - span * 0.18
        let upper = maxValue + span * 0.18
        let hasPositive = (values.max() ?? 0) > 0.001
        let hasNegative = (values.min() ?? 0) < -0.001

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Накопленный R")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("по закрытым сделкам")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 8)
                Text(Fmt.r(series.finalR))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(rColor(series.finalR))
            }

            Chart {
                RuleMark(y: .value("Ноль", 0))
                    .foregroundStyle(Color.white.opacity(0.16))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(series.rPoints) { point in
                    if hasPositive {
                        AreaMark(
                            x: .value("Дата", point.date),
                            yStart: .value("Ноль", 0),
                            yEnd: .value("R", max(point.value, 0))
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(by: .value("Знак", "plus"))
                        .opacity(0.18)

                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("R", max(point.value, 0))
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(by: .value("Знак", "plus"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    if hasNegative {
                        AreaMark(
                            x: .value("Дата", point.date),
                            yStart: .value("Ноль", 0),
                            yEnd: .value("R", min(point.value, 0))
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(by: .value("Знак", "minus"))
                        .opacity(0.18)

                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("R", min(point.value, 0))
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(by: .value("Знак", "minus"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    if !point.isStart {
                        PointMark(
                            x: .value("Дата", point.date),
                            y: .value("R", point.value)
                        )
                        .foregroundStyle(point.value >= 0 ? Theme.green : Theme.red)
                        .symbolSize(28)
                    }
                }
            }
            .chartForegroundStyleScale([
                "plus": Theme.green,
                "minus": Theme.red
            ])
            .chartLegend(.hidden)
            .chartYScale(domain: lower...upper)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(rAxisLabel(v))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dateAxisLabel(date))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 170)
        }
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private var riskStepsCard: some View {
        let points = charts.riskPoints
        let values = points.map(\.value)
        let maxValue = values.max() ?? 0
        let upper = max(maxValue * 1.25, 1)
        let axisValues = riskAxisValues(values)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Риск по ступеням")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(stepSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                if let last = points.last {
                    Text(Fmt.money(last.value))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.orange)
                }
            }

            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Дата", point.date),
                        yStart: .value("Ноль", 0),
                        yEnd: .value("Риск", point.value)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Theme.orange.opacity(0.14))

                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Риск", point.value)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Theme.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("Дата", point.date),
                        y: .value("Риск", point.value)
                    )
                    .foregroundStyle(Theme.orange)
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 0...upper)
            .chartYAxis {
                AxisMarks(position: .leading, values: axisValues) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.money(v))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dateAxisLabel(date))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private var stepSubtitle: String {
        "переходы \(Fmt.money(amounts[0])) → \(Fmt.money(amounts[1])) → \(Fmt.money(amounts[2])) и сбросы"
    }

    private func riskAxisValues(_ values: [Double]) -> [Double] {
        var set = Set<Double>()
        set.insert(0)
        for value in values {
            set.insert((value * 100).rounded() / 100)
        }
        return set.sorted()
    }

    private func dateAxisLabel(_ date: Date) -> String {
        period == .today ? Fmt.time(date) : Fmt.dayMonth(date)
    }

    private func rAxisLabel(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0R" }
        let magnitude = abs(value)
        let text = magnitude == magnitude.rounded()
            ? String(format: "%.0f", magnitude)
            : String(format: "%.1f", magnitude)
        return (value > 0 ? "+" : "\u{2212}") + text + "R"
    }
}

// MARK: - Tile

private struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(13)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Mini bar

private struct MiniBar: View {
    let wins: Int
    let losses: Int
    let total: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let count = max(total, 1)
            let winWidth = width * CGFloat(wins) / CGFloat(count)
            let lossWidth = width * CGFloat(losses) / CGFloat(count)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.green)
                        .frame(width: winWidth)
                    Rectangle()
                        .fill(Theme.red)
                        .frame(width: lossWidth)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }
}

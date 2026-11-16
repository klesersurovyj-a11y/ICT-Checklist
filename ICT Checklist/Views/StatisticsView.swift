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

    @State private var period: StatsPeriod = .all
    @State private var breakdownTarget: BreakdownTarget?
    @State private var showReport = false

    private var settings: AppSettings? { settingsList.first }
    private var amounts: [Double] {
        let list = settings?.ladderAmounts ?? []
        return list.count == 3 ? list : [12, 25, 50]
    }

    private var summary: StatsSummary {
        StatsEngine.summary(trades: trades, amounts: amounts, period: period)
    }

    private var charts: ChartSeries {
        StatsEngine.charts(trades: trades, period: period)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    GlassSegmented(
                        options: StatsPeriod.allCases,
                        selection: $period,
                        label: { $0.rawValue },
                        tint: { _ in Theme.blue }
                    )

                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    if summary.closedCount == 0 {
                        emptyCard
                    } else {
                        tilesGrid
                        streakCard
                        chartsSection
                        breakdownSection("По символам", summary.bySymbol) { group in
                            .symbol(group.title)
                        }
                        breakdownSection("По направлениям", summary.byDirection) { group in
                            .direction(Direction(rawValue: group.title) ?? .long)
                        }
                        breakdownSection("По ступеням риска", summary.byStep) { group in
                            .step(summary.byStep.firstIndex(where: { $0.id == group.id }) ?? 0)
                        }
                        if !summary.byTag.isEmpty {
                            breakdownSection("По меткам", summary.byTag) { group in
                                .tag(group.title)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(item: $breakdownTarget) { target in
            BreakdownDetailView(target: target, period: $period)
        }
        .fullScreenCover(isPresented: $showReport) {
            ReportView()
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
            Button {
                showReport = true
                Haptics.tap()
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        kindFor: @escaping (StatsGroup) -> BreakdownKind
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
                    breakdownRow(group, kind: kindFor(group))
                }
            }
            .glassCard(cornerRadius: 22)
        }
    }

    private func breakdownRow(_ group: StatsGroup, kind: BreakdownKind) -> some View {
        Button {
            breakdownTarget = BreakdownTarget(
                id: group.id,
                title: group.title,
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
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
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
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(14)
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

//
//  BenchmarkView.swift
//  ICT Checklist
//
//  Сравнение капитала в R с рыночным бенчмарком.
//

import SwiftUI
import SwiftData
import Charts

struct BenchmarkView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]

    @State private var period: EntryHeatPeriod = .days30
    @State private var benchmark: BenchmarkKind = .sp500
    @State private var bars: [ChartBar]?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var selectedDate: Date?

    private var report: BenchmarkReport {
        BenchmarkEngine.build(trades: trades, period: period, bars: bars)
    }

    private var riskPercent: Double {
        settingsList.first?.maxRiskPercent ?? 1
    }

    private var loadKey: String {
        "\(period.rawValue)|\(benchmark.rawValue)"
    }

    var body: some View {
        let snapshot = report

        return ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    GlassSegmented(
                        options: EntryHeatPeriod.allCases,
                        selection: periodBinding,
                        label: { $0.rawValue }
                    )
                    .reveal(.blur, 1)

                    benchmarkChips
                        .reveal(.rise, 1)

                    chartCard(snapshot)
                        .reveal(.zoom, 2)

                    metricsCard(snapshot)
                        .reveal(.rise, 3)

                    drawdownCard(snapshot)
                        .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .task(id: loadKey) {
            await loadBenchmark()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Результаты")
                ScreenTitle(text: "Сравнение с бенчмарком")
                Text("Твоя кривая против рынка")
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

    private var periodBinding: Binding<EntryHeatPeriod> {
        Binding(
            get: { period },
            set: { value in
                period = value
                bars = nil
                Haptics.select()
            }
        )
    }

    private var benchmarkChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BenchmarkKind.allCases) { item in
                    Chip(title: item.rawValue, isSelected: benchmark == item) {
                        benchmark = item
                        bars = nil
                        Haptics.select()
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Chart

    private func chartCard(_ report: BenchmarkReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Капитал в R")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 6)

                legendLine(title: "Ты", dashed: false)
                legendLine(title: benchmark.rawValue, dashed: true)
            }

            if isLoading && report.points.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Загружаем бенчмарк…")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else if report.points.isEmpty {
                Text("За этот период нет закрытых сделок, сравнивать нечего.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                chart(report)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func legendLine(title: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(
                    path,
                    with: .color(.white.opacity(dashed ? 0.4 : 1)),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        dash: dashed ? [3, 3] : []
                    )
                )
            }
            .frame(width: 22, height: 8)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
    }

    private func chart(_ report: BenchmarkReport) -> some View {
        let values = report.points.flatMap { [$0.trader, $0.benchmark ?? $0.trader] }
        let lower = min(values.min() ?? 0, 0) - 2
        let upper = max(max(values.max() ?? 0, 0) + 2, lower + 1)

        return Chart {
            ForEach(report.points) { point in
                AreaMark(
                    x: .value("Дата", point.date),
                    y: .value("R", point.trader),
                    series: .value("Линия", "Ты")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(report.points) { point in
                LineMark(
                    x: .value("Дата", point.date),
                    y: .value("R", point.trader),
                    series: .value("Линия", "Ты")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            ForEach(report.points) { point in
                if let value = point.benchmark {
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("R", value),
                        series: .value("Линия", benchmark.rawValue)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
            }

            if let point = selectedPoint(report) {
                RuleMark(x: .value("Дата", point.date))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Дата", point.date),
                    y: .value("R", point.trader)
                )
                .foregroundStyle(.white)
                .symbolSize(40)

                if let value = point.benchmark {
                    PointMark(
                        x: .value("Дата", point.date),
                        y: .value("R", value)
                    )
                    .foregroundStyle(Color.white.opacity(0.55))
                    .symbolSize(26)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: lower...upper)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number))R")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Fmt.dayMonth(date))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .frame(height: 210)
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 2) {
                if let point = selectedPoint(report) {
                    Text(Fmt.dayMonth(point.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Text(Fmt.r(point.trader))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    if let value = point.benchmark {
                        Text(Fmt.r(value))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                } else if let last = report.points.last {
                    Text(Fmt.r(last.trader))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .padding(.top, 2)
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.45), value: period)
    }

    private func selectedPoint(_ report: BenchmarkReport) -> BenchmarkPoint? {
        guard let selectedDate, !report.points.isEmpty else { return nil }
        return report.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    // MARK: - Metrics

    private func metricsCard(_ report: BenchmarkReport) -> some View {
        VStack(spacing: 0) {
            metricRow(
                icon: "chart.bar.xaxis",
                tint: Theme.textSecondary,
                title: "Сделки",
                subtitle: "\(Fmt.r(report.traderTotal)) · \(report.traderWinRate)% winrate",
                value: Fmt.r(report.traderTotal),
                valueTint: rColor(report.traderTotal)
            )

            Divider().overlay(Theme.hairline)

            metricRow(
                icon: "arrow.up.right",
                tint: Theme.textSecondary,
                title: benchmark.rawValue,
                subtitle: benchmarkSubtitle(report),
                value: percentText(report.benchmarkTotalPct),
                valueTint: rColor(report.benchmarkTotalPct ?? 0)
            )

            Divider().overlay(Theme.hairline)

            metricRow(
                icon: "triangle",
                tint: Theme.textSecondary,
                title: "Разница",
                subtitle: differenceSubtitle(report),
                value: report.diffR.map { Fmt.r($0) } ?? "—",
                valueTint: rColor(report.diffR ?? 0)
            )
        }
        .padding(.horizontal, 12)
        .glassCard(cornerRadius: 22)
    }

    private func metricRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        value: String,
        valueTint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 12)
    }

    private func benchmarkSubtitle(_ report: BenchmarkReport) -> String {
        guard let winRate = report.benchmarkWinRate else { return "За тот же период · нет данных" }
        return "За тот же период · \(winRate)% дней в плюс"
    }

    private func differenceSubtitle(_ report: BenchmarkReport) -> String {
        guard let diff = report.diffR else { return "Бенчмарк недоступен" }
        let word = diff >= 0 ? "Твоя доходность выше" : "Твоя доходность ниже"
        guard let bench = report.benchmarkTotalPct else { return word }
        let traderPercent = report.traderTotal * riskPercent
        let diffPercent = traderPercent - bench
        return "\(word) · в процентах \(signedPercentPoints(diffPercent)) п.п."
    }

    // MARK: - Drawdown

    private func drawdownCard(_ report: BenchmarkReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Просадка")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 6) {
                    Text("Твоя максимальная")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                    Text(drawdownText(report.traderMaxDD))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(report.traderMaxDD > 0 ? Theme.red : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1, height: 54)

                VStack(spacing: 6) {
                    Text("Бенчмарк (\(benchmark.rawValue))")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(percentText(report.benchmarkMaxDDPct, forceNegative: true))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Loading

    private func loadBenchmark() async {
        isLoading = true
        errorText = nil

        let count: Int
        if let days = period.days {
            count = max(days + 5, 30)
        } else {
            count = 500
        }

        do {
            let result = try await ChartDataService.candles(
                symbol: benchmark.symbol,
                interval: .d1,
                count: count
            )
            bars = result
        } catch {
            bars = nil
            errorText = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось загрузить бенчмарк."
        }

        isLoading = false
    }

    // MARK: - Text

    private func drawdownText(_ value: Double) -> String {
        guard value > 0.05 else { return "0.0R" }
        return "\u{2212}" + String(format: "%.1fR", value)
    }

    private func percentText(_ value: Double?, forceNegative: Bool = false) -> String {
        guard let value else { return "—" }
        let magnitude = abs(value)
        if forceNegative {
            return "\u{2212}" + String(format: "%.1f%%", magnitude)
        }
        if magnitude < 0.05 { return "0.0%" }
        return (value > 0 ? "+" : "\u{2212}") + String(format: "%.1f%%", magnitude)
    }

    private func signedPercentPoints(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude < 0.05 { return "0.0" }
        return (value > 0 ? "+" : "\u{2212}") + String(format: "%.1f", magnitude)
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return .white
    }
}

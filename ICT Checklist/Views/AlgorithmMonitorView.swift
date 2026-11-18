//
//  AlgorithmMonitorView.swift
//  ICT Checklist
//
//  Algorithm Monitor: контроль эффективности алгоритма во времени.
//

import SwiftUI
import SwiftData
import Charts

/// Метрика скользящего графика.
enum AlgoMetric: String, CaseIterable, Identifiable {
    case winRate = "Win rate"
    case expectancy = "Expectancy"
    case profitFactor = "PF"

    var id: String { rawValue }
}

struct AlgorithmMonitorView: View {
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    var body: some View {
        AlgorithmMonitorContent(report: AlgorithmMonitorEngine.report(trades: trades))
    }
}

private struct AlgorithmMonitorContent: View {
    let report: AlgoReport

    @Environment(\.dismiss) private var dismiss

    @State private var metric: AlgoMetric = .winRate
    @State private var showAssistant = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)

                    if report.closedCount == 0 {
                        emptyCard
                    } else {
                        healthCard
                            .reveal(.zoom, 1)
                        signalsCard
                            .reveal(.rise, 2)
                        rollingCard
                            .reveal(.rise, 3)
                        windowsCard
                            .reveal(.rise, 4)
                        streakCard
                            .reveal(.rise, 5)
                        assistantCard
                            .reveal(.rise, 6)
                        hintCard
                            .reveal(.blur, 7)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(Theme.snappy, value: metric)
            }
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: assistantPrompt)
        }
    }

    private var assistantPrompt: String {
        "Разбери, не ухудшается ли мой алгоритм: где метрики просели, это шум или реальная деградация, и что проверить в первую очередь. Данные монитора:\n"
            + AlgorithmMonitorEngine.promptSummary(report)
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
            SectionLabel(text: "Algorithm Monitor")
            ScreenTitle(text: "Контроль алгоритма")
            Text("Скользящие win rate, expectancy и profit factor по последним сделкам. Сигнал подскажет, когда результатов становится хуже, чем в базе.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Health

    private var healthCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(healthTint.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: report.health.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(healthTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.health.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(healthDetail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var healthDetail: String {
        let last = report.last20
        var text = "Последние \(Fmt.deals(last.count)): win rate \(AlgorithmMonitorEngine.percent(last.winRate)), expectancy \(AlgorithmMonitorEngine.signed(last.expectancy)), profit factor \(last.profitFactor.map(AlgorithmMonitorEngine.ratio) ?? "—")."
        if let winDelta = report.winRateDelta {
            text += " Win rate к предыдущим 20: \(deltaPointsText(winDelta))."
        }
        if let rDelta = report.expectancyDelta {
            text += " Expectancy: \(deltaRText(rDelta))."
        }
        return text
    }

    private var healthTint: Color {
        switch report.health {
        case .stable:
            return Theme.green
        case .decline:
            return Theme.red
        case .watch:
            return Theme.textPrimary
        case .unknown:
            return Theme.textSecondary
        }
    }

    private func deltaPointsText(_ value: Double) -> String {
        let sign = value > 0.005 ? "+" : (value < -0.005 ? "\u{2212}" : "")
        return sign + "\(Int((abs(value) * 100).rounded())) п.п."
    }

    private func deltaRText(_ value: Double) -> String {
        let sign = value > 0.005 ? "+" : (value < -0.005 ? "\u{2212}" : "")
        return sign + String(format: "%.2f", abs(value)) + "R"
    }

    // MARK: - Signals

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Сигналы")

            ForEach(report.signals) { signal in
                signalRow(signal)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func signalRow(_ signal: AlgoSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toneIcon(signal.tone))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(toneColor(signal.tone))
                .frame(width: 26, height: 26)
                .background(Circle().fill(toneColor(signal.tone).opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signal.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Rolling chart

    private var rollingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Скользящее окно")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(
                        report.closedCount >= AlgorithmMonitorEngine.rollingWindow
                            ? "Последние 20 сделок на каждую точку"
                            : "Окно растёт от \(AlgorithmMonitorEngine.minimumTrades) до 20 сделок"
                    )
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 6)
                Text(currentMetricText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(currentMetricTint)
            }

            GlassSegmented(
                options: AlgoMetric.allCases,
                selection: $metric,
                label: { $0.rawValue },
                tint: { _ in Theme.blue }
            )

            if report.points.isEmpty {
                Text("Нужно хотя бы \(AlgorithmMonitorEngine.minimumTrades) закрытых сделок")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                rollingChart
                    .frame(height: 148)

                HStack(spacing: 10) {
                    chartStat("Мин", minMetricText)
                    chartStat("Сейчас", currentMetricText)
                    chartStat("Макс", maxMetricText)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    @ViewBuilder
    private var rollingChart: some View {
        switch metric {
        case .winRate:
            winRateChart
        case .expectancy:
            expectancyChart
        case .profitFactor:
            profitFactorChart
        }
    }

    private var winRateChart: some View {
        Chart {
            RuleMark(y: .value("Порог", 0.5))
                .foregroundStyle(Color.white.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(report.points) { point in
                AreaMark(
                    x: .value("Сделка", point.id),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("Win rate", point.winRate)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Сделка", point.id),
                    y: .value("Win rate", point.winRate)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let last = report.points.last {
                PointMark(
                    x: .value("Сделка", last.id),
                    y: .value("Win rate", last.winRate)
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(34)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: 0...1)
    }

    private var expectancyChart: some View {
        Chart {
            RuleMark(y: .value("Ноль", 0))
                .foregroundStyle(Color.white.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(report.points) { point in
                AreaMark(
                    x: .value("Сделка", point.id),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("Expectancy", point.expectancy)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [expectancyTint.opacity(0.22), expectancyTint.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Сделка", point.id),
                    y: .value("Expectancy", point.expectancy)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(expectancyTint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let last = report.points.last {
                PointMark(
                    x: .value("Сделка", last.id),
                    y: .value("Expectancy", last.expectancy)
                )
                .foregroundStyle(expectancyTint)
                .symbolSize(34)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: expectancyDomain)
    }

    private var profitFactorChart: some View {
        Chart {
            RuleMark(y: .value("Единица", 1))
                .foregroundStyle(Color.white.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(profitFactorPoints) { point in
                if let value = point.profitFactor {
                    LineMark(
                        x: .value("Сделка", point.id),
                        y: .value("PF", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(profitFactorTint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }

            if let last = report.points.last, let value = last.profitFactor {
                PointMark(
                    x: .value("Сделка", last.id),
                    y: .value("PF", value)
                )
                .foregroundStyle(profitFactorTint)
                .symbolSize(34)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: profitFactorDomain)
    }

    private var expectancyTint: Color {
        report.last20.expectancy >= 0 ? Theme.green : Theme.red
    }

    private var profitFactorTint: Color {
        (report.last20.profitFactor ?? 0) >= 1 ? Theme.green : Theme.red
    }

    private var expectancyDomain: ClosedRange<Double> {
        let values = report.points.map(\.expectancy)
        guard let minimum = values.min(), let maximum = values.max() else { return -1...1 }
        let span = max(maximum - minimum, 0.4)
        return (minimum - span * 0.2)...(maximum + span * 0.2)
    }

    private var profitFactorDomain: ClosedRange<Double> {
        let values = report.points.compactMap(\.profitFactor)
        guard let minimum = values.min(), let maximum = values.max() else { return 0...2 }
        let span = max(maximum - minimum, 0.5)
        return max(0, minimum - span * 0.2)...(maximum + span * 0.2)
    }

    private var profitFactorPoints: [AlgoPoint] {
        report.points.filter { $0.profitFactor != nil }
    }

    private var currentValue: Double {
        switch metric {
        case .winRate:
            return report.last20.winRate
        case .expectancy:
            return report.last20.expectancy
        case .profitFactor:
            return report.last20.profitFactor ?? 0
        }
    }

    private var minValue: Double {
        switch metric {
        case .winRate:
            return report.points.map(\.winRate).min() ?? 0
        case .expectancy:
            return report.points.map(\.expectancy).min() ?? 0
        case .profitFactor:
            return report.points.compactMap(\.profitFactor).min() ?? 0
        }
    }

    private var maxValue: Double {
        switch metric {
        case .winRate:
            return report.points.map(\.winRate).max() ?? 0
        case .expectancy:
            return report.points.map(\.expectancy).max() ?? 0
        case .profitFactor:
            return report.points.compactMap(\.profitFactor).max() ?? 0
        }
    }

    private var currentMetricText: String {
        if metric == .profitFactor, report.last20.profitFactor == nil {
            return "—"
        }
        return metricText(currentValue)
    }

    private var minMetricText: String {
        if metric == .profitFactor, profitFactorPoints.isEmpty {
            return "—"
        }
        return metricText(minValue)
    }

    private var maxMetricText: String {
        if metric == .profitFactor, profitFactorPoints.isEmpty {
            return "—"
        }
        return metricText(maxValue)
    }

    private var currentMetricTint: Color {
        switch metric {
        case .winRate:
            return report.last20.winRate >= 0.5 ? Theme.green : Theme.textPrimary
        case .expectancy:
            return cmpTint(report.last20.expectancy, threshold: 0)
        case .profitFactor:
            guard let value = report.last20.profitFactor else { return Theme.textSecondary }
            return cmpTint(value, threshold: 1)
        }
    }

    private func metricText(_ value: Double) -> String {
        switch metric {
        case .winRate:
            return AlgorithmMonitorEngine.percent(value)
        case .expectancy:
            return AlgorithmMonitorEngine.signed(value)
        case .profitFactor:
            return AlgorithmMonitorEngine.ratio(value)
        }
    }

    private func chartStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Windows

    private var windowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Последние 20 · 40 · 100")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Одно и то же ядро метрик на трёх окнах")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(alignment: .top, spacing: 10) {
                windowTile(report.last20)
                windowTile(report.last40)
                windowTile(report.last100)
            }

            if let delta = report.profitFactorDelta {
                Text(profitFactorChangeText(delta))
                    .font(.system(size: 12))
                    .foregroundStyle(cmpTint(delta, threshold: 0))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Сравнение появится, когда перед последними 20 сделками будет хотя бы 10 предыдущих.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func windowTile(_ window: AlgoWindow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(window.size)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(window.count) сд.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)

            Divider()
                .overlay(Color.white.opacity(0.06))
                .padding(.vertical, 3)

            windowRow("Win", AlgorithmMonitorEngine.percent(window.winRate), tint: Theme.textPrimary)
            windowRow("Exp", AlgorithmMonitorEngine.signed(window.expectancy), tint: cmpTint(window.expectancy, threshold: 0))
            windowRow(
                "PF",
                window.profitFactor.map(AlgorithmMonitorEngine.ratio) ?? "—",
                tint: window.profitFactor.map { cmpTint($0, threshold: 1) } ?? Theme.textSecondary
            )
            windowRow("ΣR", Fmt.r(window.totalR), tint: cmpTint(window.totalR, threshold: 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func windowRow(_ title: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    private func profitFactorChangeText(_ delta: Double) -> String {
        let now = report.last20.profitFactor.map(AlgorithmMonitorEngine.ratio) ?? "—"
        let before = report.previous20?.profitFactor.map(AlgorithmMonitorEngine.ratio) ?? "—"
        return "Profit factor: \(now) против \(before) у предыдущих 20 (\(AlgorithmMonitorEngine.profitFactorDeltaText(delta)))"
    }

    // MARK: - Streaks

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Серии")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Текущая серия и максимумы по всей базе")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 10) {
                streakTile(
                    "Сейчас",
                    streakTitle(report.currentStreak),
                    AlgorithmMonitorEngine.signed(report.currentStreak.totalR),
                    tint: streakTint(report.currentStreak)
                )
                streakTile(
                    "Макс. TP",
                    "\(report.longestTP)",
                    "подряд",
                    tint: report.longestTP > 0 ? Theme.green : Theme.textSecondary
                )
                streakTile(
                    "Макс. SL",
                    "\(report.longestSL)",
                    "подряд",
                    tint: report.longestSL > 0 ? Theme.red : Theme.textSecondary
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func streakTile(_ title: String, _ value: String, _ caption: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func streakTitle(_ streak: AlgoStreak) -> String {
        switch streak.kind {
        case .none:
            return "—"
        case .tp:
            return "\(streak.length) TP"
        case .sl:
            return "\(streak.length) SL"
        case .be:
            return "\(streak.length) BE"
        }
    }

    private func streakTint(_ streak: AlgoStreak) -> Color {
        switch streak.kind {
        case .none:
            return Theme.textSecondary
        case .tp:
            return Theme.green
        case .sl:
            return Theme.red
        case .be:
            return Theme.textSecondary
        }
    }

    // MARK: - Assistant

    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "ИИ-ассистент")
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text("Ассистент получит скользящие метрики, серии и сравнение окон и скажет, деградация это или статистический шум.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryButton(title: "Обсудить с ассистентом") {
                showAssistant = true
                Haptics.tap()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Hints

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Как считается")

            InfoHint(text: "Win rate, expectancy и profit factor считаются по каждой закрытой сделке на скользящем окне 20 — так видно, куда движется алгоритм, а не только итог базы.")

            InfoHint(text: "Сигнал сравнивает последние 20 сделок с предыдущими 20: падение win rate на 10 п.п., падение expectancy, profit factor ниже 1 или длинная серия SL помечают состояние как «Возможное ухудшение».")

            InfoHint(text: "Окна 40 и 100 показывают, как те же метрики выглядят на длинной дистанции — просадка на 20 при сильных 100 чаще оказывается шумом.")
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нечего контролировать")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Закройте первую сделку — монитор начнёт считать скользящие метрики, серии SL и TP и покажет сигнал об ухудшении.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Tints

    private func cmpTint(_ value: Double, threshold: Double) -> Color {
        if value > threshold + 0.005 { return Theme.green }
        if value < threshold - 0.005 { return Theme.red }
        return Theme.textSecondary
    }

    private func toneColor(_ tone: BehaviorTone) -> Color {
        switch tone {
        case .positive:
            return Theme.green
        case .negative:
            return Theme.red
        case .neutral:
            return Theme.textSecondary
        }
    }

    private func toneIcon(_ tone: BehaviorTone) -> String {
        switch tone {
        case .positive:
            return "checkmark"
        case .negative:
            return "exclamationmark"
        case .neutral:
            return "info"
        }
    }
}

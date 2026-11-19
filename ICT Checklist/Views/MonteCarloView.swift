//
//  MonteCarloView.swift
//  ICT Checklist
//
//  Монте-Карло: распределение результата, просадки и риск разорения.
//

import SwiftUI
import SwiftData

struct MonteCarloView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var period: MonteCarloPeriod = .days90
    @State private var horizon = 100
    @State private var runs = MonteCarloEngine.defaultRuns
    @State private var scopeID: String?
    @State private var riskPercent = 1.0

    @State private var report: MonteCarloReport?
    @State private var captionReport: MonteCarloReport?
    @State private var selectedBin: Int?
    @State private var showHint = false

    private var activeAccounts: [TradingAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var scope: TradingAccount? {
        guard let scopeID else { return nil }
        return activeAccounts.first { "\($0.persistentModelID)" == scopeID }
    }

    private var scopeName: String {
        guard let scope else { return "Все счета" }
        return scope.name.isEmpty ? scope.type.rawValue : scope.name
    }

    private var pool: [Double] {
        let start: Date? = {
            guard let days = period.days else { return nil }
            return Calendar.current.date(
                byAdding: .day,
                value: -(days - 1),
                to: Calendar.current.startOfDay(for: .now)
            )
        }()

        return trades
            .filter { $0.result != .open }
            .filter { trade in
                guard let scope else { return true }
                return trade.account?.persistentModelID == scope.persistentModelID
            }
            .filter { trade in
                guard let start else { return true }
                return (trade.closedAt ?? trade.entryDate) >= start
            }
            .map(\.actualR)
    }

    private var computeKey: String {
        "\(scopeID ?? "all")|\(period.rawValue)|\(horizon)|\(runs)|\(Int((riskPercent * 100).rounded()))"
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
                    controlsRow
                        .reveal(.blur, 1)

                    if let report, !report.isEmpty {
                        distributionCard(report)
                            .reveal(.zoom, 2)
                        tilesRow(report)
                            .reveal(.rise, 3)
                        riskCard
                            .reveal(.rise, 4)
                        hintButton
                            .reveal(.rise, 5)
                    } else if pool.count >= 3 {
                        loadingCard
                            .reveal(.rise, 2)
                    } else {
                        emptyCard
                            .reveal(.rise, 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .task(id: computeKey) {
            await recompute()
        }
        .sheet(isPresented: $showHint) {
            MonteCarloHintSheet()
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
            SectionLabel(text: "Фонд · Симуляция")
            ScreenTitle(text: "Монте-Карло")
            Text("1000 прогонов по вашим сделкам: диапазон результата и риск разорения.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach([500, 1000, 2000], id: \.self) { value in
                        Button("\(value) прогонов") {
                            runs = value
                            Haptics.select()
                        }
                    }
                } label: {
                    pillLabel("\(runs) прогонов")
                }

                Menu {
                    ForEach([50, 100, 200], id: \.self) { value in
                        Button("\(value) сделок") {
                            horizon = value
                            Haptics.select()
                        }
                    }
                } label: {
                    pillLabel("\(horizon) сделок")
                }

                Menu {
                    ForEach(MonteCarloPeriod.allCases) { option in
                        Button(option.rawValue) {
                            period = option
                            Haptics.select()
                        }
                    }
                } label: {
                    pillLabel(period.rawValue)
                }

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
                    pillLabel("Счёт: \(scopeName)")
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func pillLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCapsule()
    }

    // MARK: - Distribution

    private func distributionCard(_ report: MonteCarloReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Распределение результата")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 4) {
                Text("медиана")
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.r(report.medianR))
                    .fontWeight(.semibold)
                    .foregroundStyle(tint(report.medianR))
            }
            .font(.system(size: 13))

            HStack(spacing: 4) {
                Text("5–95%:")
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.r(report.lowR))
                    .foregroundStyle(Theme.red)
                Text("...")
                    .foregroundStyle(Theme.textTertiary)
                Text(Fmt.r(report.highR))
                    .foregroundStyle(Theme.green)
            }
            .font(.system(size: 13))

            histogram(report)
                .frame(height: 150)
                .padding(.top, 4)

            if let selectedBin,
               let bin = report.bins.first(where: { $0.id == selectedBin }) {
                HStack(spacing: 8) {
                    Text("\(Fmt.r(bin.lower)) … \(Fmt.r(bin.upper))")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(bin.mid >= 0 ? Theme.green : Theme.red)
                    Text("\(bin.count) из \(report.runs)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            } else {
                axisLabels(report)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func histogram(_ report: MonteCarloReport) -> some View {
        let maximum = max(report.bins.map(\.count).max() ?? 1, 1)
        return GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(report.bins) { bin in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(bin.mid >= 0 ? Theme.green : Theme.red)
                        .frame(height: max(2, CGFloat(bin.count) / CGFloat(maximum) * proxy.size.height))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .opacity(selectedBin == nil || selectedBin == bin.id ? 1 : 0.32)
                        .contentShape(Rectangle())
                        .barGrow(delay: Double(bin.id) * 0.03)
                        .onTapGesture {
                            withAnimation(Theme.snappy) {
                                selectedBin = selectedBin == bin.id ? nil : bin.id
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func axisLabels(_ report: MonteCarloReport) -> some View {
        let count = 6
        return HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                let fraction = Double(index) / Double(max(count - 1, 1))
                let value = report.minR + (report.maxR - report.minR) * fraction
                Text(rShort(value))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : (index == count - 1 ? .trailing : .center))
            }
        }
    }

    // MARK: - Tiles

    private func tilesRow(_ report: MonteCarloReport) -> some View {
        HStack(spacing: 8) {
            MetricTile(
                title: "Макс. просадка",
                value: "\u{2212}\(String(format: "%.0fR", report.expectedMaxDrawdownR))",
                tint: Theme.red
            )
            MetricTile(
                title: "Вероятность \u{2212}10%",
                value: MonteCarloEngine.formattedProbability(report.loss10Probability),
                tint: Theme.textPrimary
            )
            MetricTile(
                title: "Риск разорения",
                value: MonteCarloEngine.formattedProbability(report.ruinProbability),
                tint: Theme.textPrimary
            )
        }
    }

    // MARK: - Risk

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Риск на сделку")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text(String(format: "%.1f%%", riskPercent))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)

            HStack(spacing: 10) {
                Text("0.25%")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)

                Slider(value: $riskPercent, in: 0.25...3, step: 0.05)
                    .tint(Theme.textPrimary)

                Text("3%")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text(captionText)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var captionText: String {
        guard let captionReport, !captionReport.isEmpty else {
            return "при 2.0% риска вероятность просадки \u{2212}20% считается заново."
        }
        let probability = MonteCarloEngine.formattedProbability(captionReport.loss20Probability)
        return "при 2.0% вероятность просадки \u{2212}20% — \(probability)."
    }

    // MARK: - Hint

    private var hintButton: some View {
        Button {
            showHint = true
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: "book")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                Text("Как читать симуляцию")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassCard(cornerRadius: 20, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Empty

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text("Считаем \(runs) прогонов…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Мало данных для симуляции")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Нужно хотя бы несколько закрытых сделок за выбранный период и счёт — из их R строится распределение.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Compute

    @MainActor
    private func recompute() async {
        let values = pool
        guard values.count >= 3 else {
            report = nil
            captionReport = nil
            return
        }

        let horizonValue = horizon
        let runsValue = runs
        let riskValue = riskPercent

        try? await Task.sleep(nanoseconds: 60_000_000)
        guard !Task.isCancelled else { return }

        let main = await Task.detached(priority: .userInitiated) {
            MonteCarloEngine.report(
                pool: values,
                horizon: horizonValue,
                riskPercent: riskValue,
                runs: runsValue
            )
        }.value

        let caption = await Task.detached(priority: .utility) {
            MonteCarloEngine.report(
                pool: values,
                horizon: horizonValue,
                riskPercent: 2.0,
                runs: runsValue
            )
        }.value

        guard !Task.isCancelled else { return }
        report = main
        captionReport = caption
    }

    // MARK: - Formatting

    private func tint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textPrimary
    }

    private func rShort(_ value: Double) -> String {
        let sign = value > 0.5 ? "+" : (value < -0.5 ? "\u{2212}" : "")
        return sign + String(format: "%.0fR", abs(value))
    }
}

// MARK: - Hint sheet

private struct MonteCarloHintSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "Монте-Карло · Подсказка")
                        Spacer(minLength: 0)
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

                    ScreenTitle(text: "Как читать симуляцию")

                    InfoHint(text: "Симуляция берёт R ваших закрытых сделок и случайно собирает из них последовательности по 100 сделок. Так видно, что может дать стратегия в разных порядках, а не только в том, который случился на самом деле.")

                    InfoHint(text: "Медиана — типичный исход. Диапазон 5–95% показывает, куда попадёт результат в 90% прогонов: ниже и выше возможны плохие и удачные серии.")

                    InfoHint(text: "Максимальная просадка — медианная глубина падения от пика внутри одного прогона. Вероятность −10% и −20% показывает, как часто капитал просаживался на эти величины, а риск разорения — как часто капитал терял половину.")

                    InfoHint(text: "Ползунок риска меняет расчёт сразу и нигде не сохраняется: это проверка гипотезы, а не настройка.")
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}

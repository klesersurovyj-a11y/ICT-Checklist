//
//  RiskIntelligenceView.swift
//  ICT Checklist
//
//  Risk Intelligence: контроль эффективности риска, просадка,
//  лимиты и риск-лестница.
//

import SwiftUI
import SwiftData
import Charts

struct RiskIntelligenceView: View {
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    var body: some View {
        RiskIntelligenceContent(
            report: RiskIntelligenceEngine.report(
                trades: trades,
                settings: settingsList.first,
                accounts: accounts
            )
        )
    }
}

private struct RiskIntelligenceContent: View {
    let report: RiskReport

    @Environment(\.dismiss) private var dismiss
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
                            .reveal(.zoom, 2)
                    } else {
                        statusCard
                            .reveal(.zoom, 1)
                        tilesGrid
                            .reveal(.rise, 2)
                        drawdownCard
                            .reveal(.rise, 3)
                        limitsCard
                            .reveal(.rise, 4)
                        extraWarnings
                            .reveal(.rise, 4)
                        ladderCard
                            .reveal(.rise, 5)
                        sizingCard
                            .reveal(.rise, 6)
                        assistantCard
                            .reveal(.rise, 7)
                        hintCard
                            .reveal(.blur, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: assistantPrompt)
        }
    }

    private var assistantPrompt: String {
        "Разбери, насколько эффективно я контролирую риск: где превышаю риск на сделку, что с просадкой и лимитами, соблюдается ли риск-лестница и что исправить. Данные:\n"
            + RiskIntelligenceEngine.promptSummary(report)
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
            SectionLabel(text: "Risk Intelligence")
            ScreenTitle(text: "Контроль риска")
            Text("Фактический риск в R и в процентах капитала, просадка, дневной и недельный лимиты, контроль риск-лестницы.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status

    private var statusCard: some View {
        let primary = report.warnings.first
        let warningCount = report.warnings.filter { $0.tone == .negative }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusTint(primary?.tone).opacity(0.15))
                        .frame(width: 54, height: 54)
                    Image(systemName: statusIcon(primary?.tone))
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(statusTint(primary?.tone))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(primary?.title ?? "Риск под контролем")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(primary?.detail ?? "Ограничения не нарушены.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if warningCount > 1 {
                Text("Ещё \(warningCount - 1) \(Fmt.dealWord(warningCount - 1)) по ограничениям — ниже.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func statusTint(_ tone: BehaviorTone?) -> Color {
        switch tone {
        case .positive:
            return Theme.green
        case .negative:
            return Theme.red
        case .neutral:
            return Theme.textPrimary
        case .none:
            return Theme.green
        }
    }

    private func statusIcon(_ tone: BehaviorTone?) -> String {
        switch tone {
        case .positive:
            return "checkmark.shield"
        case .negative:
            return "exclamationmark.triangle"
        case .neutral:
            return "eye"
        case .none:
            return "checkmark.shield"
        }
    }

    // MARK: - Tiles

    private var tilesGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricTile(
                    title: "Риск, R",
                    value: String(format: "%.2f", report.averageRiskR) + "R",
                    tint: abs(report.averageRiskR - 1) <= 0.05 ? Theme.green : Theme.textPrimary
                )
                MetricTile(
                    title: "Риск, %",
                    value: report.averageRiskPercent.map(RiskIntelligenceEngine.percentText) ?? "—",
                    tint: riskPercentTint(report.averageRiskPercent)
                )
                MetricTile(title: "Средний риск", value: Fmt.money(report.averageRiskUSD))
            }
            HStack(spacing: 10) {
                MetricTile(
                    title: "Просадка",
                    value: Fmt.r(-report.currentDrawdownR),
                    tint: report.currentDrawdownR > 0.05 ? Theme.red : Theme.green
                )
                MetricTile(
                    title: "Макс. просадка",
                    value: Fmt.r(-report.maxDrawdownR),
                    tint: report.maxDrawdownR > 0.05 ? Theme.red : Theme.textPrimary
                )
                MetricTile(
                    title: "Не по лестнице",
                    value: "\(report.ladderMismatchCount)",
                    tint: report.ladderMismatchCount == 0 ? Theme.textPrimary : Theme.red
                )
            }
        }
    }

    private func riskPercentTint(_ value: Double?) -> Color {
        guard let value else { return Theme.textSecondary }
        return value > report.maxRiskPercent + 0.0001 ? Theme.red : Theme.green
    }

    // MARK: - Warnings

    @ViewBuilder
    private var extraWarnings: some View {
        let rest = Array(report.warnings.dropFirst())
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Предупреждения")
                ForEach(rest) { warning in
                    warningRow(warning)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 22)
        }
    }

    private func warningRow(_ warning: RiskWarning) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warning.tone == .negative ? "exclamationmark" : "info")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(warningTint(warning.tone))
                .frame(width: 26, height: 26)
                .background(Circle().fill(warningTint(warning.tone).opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(warning.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(warning.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func warningTint(_ tone: BehaviorTone) -> Color {
        switch tone {
        case .positive:
            return Theme.green
        case .negative:
            return Theme.red
        case .neutral:
            return Theme.textPrimary
        }
    }

    // MARK: - Drawdown

    private var drawdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Просадка")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("От пика капитала по закрытым сделкам")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            if report.points.isEmpty {
                Text("Пока нет закрытых сделок")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 10)
            } else {
                equityChart
                    .frame(height: 132)

                HStack(spacing: 10) {
                    chartStat("Пик", Fmt.r(report.peakR))
                    chartStat("Сейчас", Fmt.r(report.currentR))
                    chartStat("Просадка", Fmt.r(-report.currentDrawdownR), tint: report.currentDrawdownR > 0.05 ? Theme.red : Theme.textSecondary)
                }
            }

            if let equity = report.equity {
                HStack(spacing: 6) {
                    Text("Капитал")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.money(equity))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 6)
                    if let maxPercent = report.maxDrawdownPercent {
                        Text("макс. \(RiskIntelligenceEngine.percentText(maxPercent))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(maxPercent >= 10 ? Theme.red : Theme.textSecondary)
                    }
                }
            } else {
                InfoHint(
                    text: "Чтобы видеть риск в процентах капитала, добавьте счёт с балансом в разделе «Счета».",
                    tint: Theme.textTertiary,
                    icon: "info.circle"
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var equityChart: some View {
        Chart {
            RuleMark(y: .value("Ноль", 0))
                .foregroundStyle(Color.white.opacity(0.16))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(report.points) { point in
                AreaMark(
                    x: .value("Сделка", point.id),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("R", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.20), Theme.accent.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Сделка", point.id),
                    y: .value("R", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let last = report.points.last {
                PointMark(
                    x: .value("Сделка", last.id),
                    y: .value("R", last.value)
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: equityDomain)
    }

    private var equityDomain: ClosedRange<Double> {
        let values = report.points.map(\.value)
        guard let minimum = values.min(), let maximum = values.max() else { return -1...1 }
        let span = max(maximum - minimum, 1)
        return (minimum - span * 0.15)...(maximum + span * 0.15)
    }

    private func chartStat(_ title: String, _ value: String, tint: Color = Theme.textSecondary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Limits

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Лимиты")

            if let daily = report.daily {
                limitBlock(daily)
            }

            if let weekly = report.weekly {
                Divider()
                    .overlay(Color.white.opacity(0.06))
                limitBlock(weekly)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func limitBlock(_ limit: RiskLimitSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(limit.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 6)
                statusPill(limit)
            }

            if limit.isEnabled {
                limitBar(
                    title: "Сделки",
                    value: limit.tradesText,
                    progress: limit.tradeProgress,
                    tint: limit.trades >= limit.maxTrades ? Theme.red : Theme.textPrimary
                )
                limitBar(
                    title: "Результат",
                    value: limit.rText,
                    progress: limit.lossProgress,
                    tint: limit.lossProgress >= 1 ? Theme.red : Theme.textSecondary
                )
            } else {
                Text("Лимит выключен — включите его в настройках.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func statusPill(_ limit: RiskLimitSnapshot) -> some View {
        let text: String
        let tint: Color
        if !limit.isEnabled {
            text = "Выкл"
            tint = Theme.textSecondary
        } else if limit.isReached {
            text = "Достигнут"
            tint = Theme.red
        } else if limit.isNear {
            text = "Почти"
            tint = Theme.textPrimary
        } else {
            text = "В норме"
            tint = Theme.green
        }

        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }

    private func limitBar(title: String, value: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 6)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05))
                    Capsule()
                        .fill(tint.opacity(0.65))
                        .frame(width: max(2, proxy.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Ladder

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Риск-лестница")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Ступень \(report.ladderStep + 1) из 3 · накоплено \(String(format: "%.1f", report.ladderAccumulated)) / \(String(format: "%.1f", report.ladderTarget)) R")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 6)
                Image(systemName: "stairs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05))
                    Capsule()
                        .fill(Theme.accent.opacity(0.6))
                        .frame(
                            width: max(
                                2,
                                proxy.size.width * min(max(report.ladderAccumulated / max(report.ladderTarget, 0.1), 0), 1)
                            )
                        )
                }
            }
            .frame(height: 5)

            ForEach(report.ladderStats) { step in
                HStack(spacing: 8) {
                    Text("Ступень \(step.step + 1)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(step.step == report.ladderStep ? .white : Theme.textSecondary)
                    Text("\(step.count) сд.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 6)
                    Text(step.averageRisk > 0 ? Fmt.money(step.averageRisk) : "—")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.r(step.totalR))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rTint(step.totalR))
                        .frame(minWidth: 52, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }

            if report.ladderMismatchCount == 0 {
                InfoHint(
                    text: "Риск каждой сделки совпадает с размером её ступени.",
                    tint: Theme.green,
                    icon: "checkmark.seal"
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Риск не по ступени")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.red)
                    ForEach(report.mismatches) { row in
                        mismatchRow(row)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func mismatchRow(_ row: RiskTradeRow) -> some View {
        HStack(spacing: 8) {
            Text(row.trade.symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
            Text(Fmt.shortDay(row.trade.tradingDay))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 6)
            Text("\(Fmt.money(row.riskUSD)) · \(String(format: "%.2f", row.riskR))R")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.red)
            Text("→ \(Fmt.money(row.expectedUSD))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Sizing

    private var sizingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Фактический риск")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Последние сделки: риск в R, в деньгах и в капитале")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            if report.overPercentCount > 0 {
                Text("\(report.overPercentCount) \(Fmt.dealWord(report.overPercentCount)) выше лимита \(RiskIntelligenceEngine.percentText(report.maxRiskPercent)) капитала")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                MetricTile(title: "Средний", value: Fmt.money(report.averageRiskUSD))
                MetricTile(title: "Медиана", value: report.medianRiskUSD.map { Fmt.money($0) } ?? "—")
                MetricTile(
                    title: "Средний, %",
                    value: report.averageRiskPercent.map(RiskIntelligenceEngine.percentText) ?? "—",
                    tint: riskPercentTint(report.averageRiskPercent)
                )
            }

            if report.recent.isEmpty {
                Text("Закрытых сделок пока нет")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(report.recent) { row in
                    tradeRow(row)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func tradeRow(_ row: RiskTradeRow) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.trade.symbol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    if row.isMismatch {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.red)
                    }
                    if (row.riskPercent ?? 0) > report.maxRiskPercent + 0.0001 {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.red)
                    }
                }
                Text("по лестнице \(Fmt.money(row.expectedUSD)) · \(String(format: "%.2f", row.riskR))R · \(Fmt.shortDay(row.trade.tradingDay))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(row.riskUSD))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(row.riskPercent.map(RiskIntelligenceEngine.percentText) ?? "—")
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(
                        (row.riskPercent ?? 0) > report.maxRiskPercent + 0.0001
                            ? Theme.red
                            : Theme.textTertiary
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
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

            Text("Ассистент получит риск на сделку, просадку, лимиты и состояние лестницы и скажет, где контроль риска ломается.")
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

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нечего контролировать")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Закройте первую сделку — Risk Intelligence покажет риск в R и процентах капитала, просадку, лимиты и состояние лестницы.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Как считается")

            InfoHint(text: "Риск в R — это риск сделки относительно её ступени: 1.0 значит вход ровно на размер ступени, больше — риск выше системы.")

            InfoHint(text: "Риск в процентах капитала — риск в деньгах от капитала счёта: баланс плюс результат закрытых сделок этого счёта.")

            InfoHint(text: "Просадка — падение от пика капитала по закрытым сделкам, в R и в процентах. Лимиты берутся из настроек, неделя начинается с понедельника.")
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }
}

private func rTint(_ value: Double) -> Color {
    if value > 0.05 { return Theme.green }
    if value < -0.05 { return Theme.red }
    return Theme.textSecondary
}

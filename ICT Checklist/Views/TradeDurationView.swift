//
//  TradeDurationView.swift
//  ICT Checklist
//
//  «Время в сделке»: сколько живёт сделка до результата.
//

import SwiftUI
import SwiftData

struct TradeDurationView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: EntryHeatPeriod = .days30
    @State private var selectedGroup: String?
    @State private var sheet: DurationTradesData?

    private var report: TradeDurationReport {
        TradeDurationReport.build(trades: trades, period: period)
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
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

                    distributionCard(snapshot)
                        .reveal(.zoom, 2)

                    averageTiles(snapshot)
                        .reveal(.rise, 3)

                    insightsCard(snapshot)
                        .reveal(.rise, 4)

                    actionButton(snapshot)
                        .reveal(.rise, 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $sheet) { data in
            DurationTradesSheet(title: data.title, trades: data.trades, usedTags: usedTags)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Market Behavior")
                ScreenTitle(text: "Время в сделке")
                Text("Сколько сделка живёт до результата")
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
                selectedGroup = nil
                Haptics.select()
            }
        )
    }

    // MARK: - Distribution

    private func distributionCard(_ report: TradeDurationReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Распределение")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Text("Сделок")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.bottom, 4)

            ForEach(report.groups) { group in
                Button {
                    selectedGroup = selectedGroup == group.title ? nil : group.title
                    Haptics.tap()
                } label: {
                    groupRow(group, maxAbs: report.maxAbsR)
                }
                .buttonStyle(.plain)
            }

            if report.closed.isEmpty {
                Text("За этот период нет закрытых сделок.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func groupRow(_ group: DurationGroup, maxAbs: Double) -> some View {
        let tint = group.totalR < -0.05 ? Theme.red : (group.totalR > 0.05 ? Theme.green : Theme.textSecondary)
        let ratio = min(abs(group.totalR) / max(maxAbs, 0.1), 1)
        let isSelected = selectedGroup == group.title

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(group.winRate)% winrate · \(Fmt.r(group.averageR))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 96, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * ratio, group.count > 0 ? 6 : 0))
                }
            }
            .frame(height: 12)

            Text(Fmt.r(group.totalR))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(width: 56, alignment: .trailing)

            Text("\(group.count)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.05 : 0))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Averages

    private func averageTiles(_ report: TradeDurationReport) -> some View {
        HStack(spacing: 10) {
            statTile(
                title: "Среднее до TP",
                value: hoursText(report.averageToTPHours),
                tint: Theme.green
            )
            statTile(
                title: "Среднее до SL",
                value: hoursText(report.averageToSLHours),
                tint: Theme.red
            )
        }
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 20)
    }

    private func hoursText(_ hours: Double?) -> String {
        guard let hours else { return "—" }
        let value = hours >= 10
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours)
        return "\(value) ч"
    }

    // MARK: - Insights

    private func insightsCard(_ report: TradeDurationReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Что это значит")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            insightRow(
                icon: "arrow.up.right",
                tint: Theme.green,
                title: "Большинство сделок закрывается в первые 4 часа",
                detail: "\(report.fastPositiveShare)% сделок дают положительный результат в течение 4 часов"
            )

            Divider().overlay(Theme.hairline)

            insightRow(
                icon: "clock",
                tint: Theme.textSecondary,
                title: "Длительное удержание повышает риск",
                detail: slowText(report)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func slowText(_ report: TradeDurationReport) -> String {
        guard report.slowCount > 0, let average = report.slowAverageR else {
            return "За период нет сделок дольше 12 часов."
        }
        if average < -0.05 {
            return "Сделки дольше 12 часов чаще заканчиваются убытком (средний \(Fmt.r(average)))"
        }
        return "Сделки дольше 12 часов в среднем \(Fmt.r(average))"
    }

    private func insightRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Action

    private func actionButton(_ report: TradeDurationReport) -> some View {
        Button {
            openTrades(report)
        } label: {
            Text("Показать сделки группы")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(report.closed.isEmpty)
        .opacity(report.closed.isEmpty ? 0.45 : 1)
        .padding(.top, 4)
    }

    private func openTrades(_ report: TradeDurationReport) {
        guard !report.closed.isEmpty else { return }

        let group = report.groups.first { $0.title == selectedGroup }
        let list = (group?.trades ?? report.closed)
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
        let title = group?.title ?? "Все сделки периода"

        sheet = DurationTradesData(title: title, trades: list)
        Haptics.tap()
    }
}

// MARK: - Sheet model

private struct DurationTradesData: Identifiable {
    let id = UUID()
    let title: String
    let trades: [Trade]
}

// MARK: - Trades sheet

private struct DurationTradesSheet: View {
    let title: String
    let trades: [Trade]
    let usedTags: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTrade: Trade?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    list
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Сделки")
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(Fmt.deals(trades.count)) · \(Fmt.r(trades.reduce(0) { $0 + $1.actualR }))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var list: some View {
        if trades.isEmpty {
            Text("В этой группе пока нет сделок.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 20)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                    Button {
                        selectedTrade = trade
                        Haptics.tap()
                    } label: {
                        row(trade)
                    }
                    .buttonStyle(.plain)

                    if index < trades.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    private func row(_ trade: Trade) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.shortDay(trade.tradingDay))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Text(trade.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(trade.result.rawValue)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(resultTint(trade.result))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(resultTint(trade.result).opacity(0.16)))

            Text(durationText(trade))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(Fmt.r(trade.actualR))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(trade.actualR))

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func durationText(_ trade: Trade) -> String {
        guard let closedAt = trade.closedAt else { return "—" }
        let hours = max(closedAt.timeIntervalSince(trade.entryDate) / 3600, 0)
        if hours < 1 {
            return String(format: "%.0f мин", hours * 60)
        }
        if hours < 24 {
            return hours >= 10 ? String(format: "%.0f ч", hours) : String(format: "%.1f ч", hours)
        }
        return String(format: "%.1f дн", hours / 24)
    }

    private func resultTint(_ result: TradeResult) -> Color {
        switch result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return Theme.textSecondary
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

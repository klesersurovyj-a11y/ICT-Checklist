//
//  EntryHoursView.swift
//  ICT Checklist
//
//  «Часы входа»: тепловая карта R по дням недели и часам,
//  лучшие и худшие часы и переход к сделкам.
//

import SwiftUI
import SwiftData

struct EntryHoursView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: EntryHeatPeriod = .days30
    @State private var selection: EntrySelection?
    @State private var sheet: HourTradesData?

    private var report: EntryHeatReport {
        EntryHeatReport.build(trades: trades, period: period)
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

                    heatCard(snapshot)
                        .reveal(.zoom, 2)

                    if let stats = selectionStats(snapshot) {
                        selectionCard(stats)
                            .reveal(.rise, 3)
                    }

                    bestCard(snapshot)
                        .reveal(.rise, 3)
                    worstCard(snapshot)
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
            HourTradesSheet(title: data.title, trades: data.trades, usedTags: usedTags)
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
                ScreenTitle(text: "Часы входа")
                Text("Когда сделки приносят R, а когда отдают")
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
                selection = nil
                Haptics.select()
            }
        )
    }

    // MARK: - Heatmap

    private func heatCard(_ report: EntryHeatReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Тепловая карта R")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            hourLabels

            VStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { weekday in
                    heatRow(weekday, report: report)
                }
            }

            legend(report)

            if report.closed.isEmpty {
                Text("За этот период закрытых сделок нет — карта пустая.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private var hourLabels: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 28)
                .frame(height: 1)

            HStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { index in
                    Text("\(index * 2)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func heatRow(_ weekday: Int, report: EntryHeatReport) -> some View {
        HStack(spacing: 2) {
            Text(EntryHeatReport.weekdayLabels[weekday])
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 26, alignment: .leading)

            ForEach(0..<24, id: \.self) { hour in
                let cell = report.cell(weekday: weekday, hour: hour)
                let isSelected = selection == .cell(weekday: weekday, hour: hour)

                Button {
                    selection = .cell(weekday: weekday, hour: hour)
                    Haptics.tap()
                } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(heatColor(cell.totalR, maxAbs: report.maxAbsR))
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Color.white.opacity(isSelected ? 0.85 : 0), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func legend(_ report: EntryHeatReport) -> some View {
        HStack(spacing: 8) {
            Text(scaleText(-report.maxAbsR))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.red)

            LinearGradient(
                colors: [
                    Theme.red.opacity(0.85),
                    Color.white.opacity(0.10),
                    Theme.green.opacity(0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())

            Text(scaleText(report.maxAbsR))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.green)
        }
        .padding(.top, 2)
    }

    private func scaleText(_ value: Double) -> String {
        let magnitude = abs(value)
        let text = magnitude >= 10
            ? String(format: "%.0f", magnitude)
            : String(format: "%.1f", magnitude)
        return (value < 0 ? "\u{2212}" : "+") + text + "R"
    }

    private func heatColor(_ value: Double, maxAbs: Double) -> Color {
        guard abs(value) > 0.05 else { return Color.white.opacity(0.04) }
        let ratio = min(abs(value) / max(maxAbs, 0.1), 1)
        let tint = value > 0 ? Theme.green : Theme.red
        return tint.opacity(0.18 + 0.62 * ratio)
    }

    // MARK: - Selection

    private func selectionStats(_ report: EntryHeatReport) -> SelectionStats? {
        guard let selection else { return nil }

        switch selection {
        case .cell(let weekday, let hour):
            let cell = report.cell(weekday: weekday, hour: hour)
            return SelectionStats(
                title: "\(EntryHeatReport.weekdayLabels[weekday]) · \(hourText(hour))",
                trades: cell.trades,
                winRate: cell.winRate,
                averageR: cell.averageR
            )
        case .hour(let hour):
            let stat = report.hourStat(hour)
            return SelectionStats(
                title: hourText(hour),
                trades: stat.trades,
                winRate: stat.winRate,
                averageR: stat.averageR
            )
        }
    }

    private func selectionCard(_ stats: SelectionStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(stats.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Button {
                    selection = nil
                    Haptics.tap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .glassCircle()
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                MetricTile(title: "Сделки", value: "\(stats.trades)")
                MetricTile(
                    title: "Winrate",
                    value: stats.trades > 0 ? "\(stats.winRate)%" : "—",
                    tint: stats.winRate >= 50 ? Theme.green : .white
                )
                MetricTile(
                    title: "Средний R",
                    value: stats.trades > 0 ? Fmt.r(stats.averageR) : "—",
                    tint: rColor(stats.averageR)
                )
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Best and worst

    private func bestCard(_ report: EntryHeatReport) -> some View {
        hoursCard(
            title: "Лучшие часы",
            stats: report.bestHours,
            tint: Theme.green
        )
    }

    private func worstCard(_ report: EntryHeatReport) -> some View {
        hoursCard(
            title: "Худшие часы",
            stats: report.worstHours,
            tint: Theme.red
        )
    }

    private func hoursCard(title: String, stats: [EntryHourStat], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            if stats.isEmpty {
                Text("Недостаточно закрытых сделок, чтобы выделить часы.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        Button {
                            selection = .hour(stat.hour)
                            Haptics.tap()
                        } label: {
                            hourRow(rank: index + 1, stat: stat, tint: tint)
                        }
                        .buttonStyle(.plain)

                        if index < stats.count - 1 {
                            Divider()
                                .overlay(Theme.hairline)
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func hourRow(rank: Int, stat: EntryHourStat, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 30, height: 30)
                Text("\(rank)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(hourText(stat.hour))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text(Fmt.r(stat.totalR))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)

            Text(Fmt.deals(stat.trades))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    // MARK: - Action

    private func actionButton(_ report: EntryHeatReport) -> some View {
        Button {
            openTrades(report)
        } label: {
            Text("Все сделки этих часов")
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

    private func openTrades(_ report: EntryHeatReport) {
        guard !report.closed.isEmpty else { return }

        if let selection {
            let list = report
                .trades(weekday: selection.weekday, hour: selection.hour)
                .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
            let title = selectionStats(report)?.title ?? hourText(selection.hour)
            sheet = HourTradesData(title: title, trades: list)
        } else {
            let list = report.closed
                .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
            sheet = HourTradesData(title: "Сделки за период", trades: list)
        }

        Haptics.tap()
    }

    private func hourText(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Models

private enum EntrySelection: Equatable {
    case cell(weekday: Int, hour: Int)
    case hour(Int)

    var hour: Int {
        switch self {
        case .cell(_, let hour): return hour
        case .hour(let hour): return hour
        }
    }

    var weekday: Int? {
        switch self {
        case .cell(let weekday, _): return weekday
        case .hour: return nil
        }
    }
}

private struct SelectionStats {
    let title: String
    let trades: Int
    let winRate: Int
    let averageR: Double
}

private struct HourTradesData: Identifiable {
    let id = UUID()
    let title: String
    let trades: [Trade]
}

// MARK: - Trades sheet

private struct HourTradesSheet: View {
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
                    summary
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

    private var summary: some View {
        HStack(spacing: 8) {
            Text(Fmt.deals(trades.count))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            Text(Fmt.r(trades.reduce(0) { $0 + $1.actualR }))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(trades.reduce(0) { $0 + $1.actualR }))
        }
    }

    @ViewBuilder
    private var list: some View {
        if trades.isEmpty {
            Text("В этом часе нет закрытых сделок.")
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

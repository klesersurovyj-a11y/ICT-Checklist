//
//  ReportView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

enum ReportPeriod: String, CaseIterable, Identifiable {
    case month = "Месяц"
    case week = "Неделя"
    case year = "Год"

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .month: return .month
        case .week: return .weekOfYear
        case .year: return .year
        }
    }
}

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var trades: [Trade]
    @Query private var cycles: [TradingCycle]

    @State private var period: ReportPeriod = .month
    @State private var anchor: Date = .now
    @State private var selectedTrade: Trade?

    private var calendar: Calendar { Calendar.current }

    // MARK: - Data

    private var currentInterval: DateInterval? {
        interval(for: anchor)
    }

    private var previousInterval: DateInterval? {
        guard let current = currentInterval,
              let previousAnchor = calendar.date(
                byAdding: period.component,
                value: -1,
                to: current.start
              ) else {
            return nil
        }
        return interval(for: previousAnchor)
    }

    private func interval(for date: Date) -> DateInterval? {
        calendar.dateInterval(of: period.component, for: date)
    }

    private func cycles(in interval: DateInterval?) -> [TradingCycle] {
        guard let interval else { return [] }
        return cycles.filter { interval.contains($0.day) }
    }

    private func trades(in interval: DateInterval?) -> [Trade] {
        guard let interval else { return [] }
        return trades.filter { interval.contains($0.tradingDay) }
    }

    private var periodCycles: [TradingCycle] {
        cycles(in: currentInterval)
    }

    private var periodTrades: [Trade] {
        trades(in: currentInterval).sorted { first, second in
            if first.tradingDay != second.tradingDay { return first.tradingDay > second.tradingDay }
            return first.entryDate > second.entryDate
        }
    }

    private struct PeriodStat {
        let totalR: Double
        let winRate: Double
        let trades: Int
        let days: Int
        let hasData: Bool
    }

    private func stat(for interval: DateInterval?) -> PeriodStat {
        let items = trades(in: interval)
        let closed = items.filter { $0.result != .open }
        let totalR = closed.reduce(0) { $0 + $1.actualR }
        let wins = closed.filter { $0.actualR > 0.05 }.count
        let winRate = closed.isEmpty ? 0 : Double(wins) / Double(closed.count)
        let days = cycles(in: interval).count

        return PeriodStat(
            totalR: totalR,
            winRate: winRate,
            trades: items.count,
            days: days,
            hasData: !items.isEmpty || days > 0
        )
    }

    private var closedTrades: [Trade] {
        periodTrades.filter { $0.result != .open }
    }

    private var totalR: Double {
        closedTrades.reduce(0) { $0 + $1.actualR }
    }

    private var winRate: Double {
        guard !closedTrades.isEmpty else { return 0 }
        return Double(closedTrades.filter { $0.actualR > 0.05 }.count) / Double(closedTrades.count)
    }

    private var profitFactor: Double? {
        let wins = closedTrades.filter { $0.actualR > 0 }.reduce(0) { $0 + $1.actualR }
        let losses = abs(closedTrades.filter { $0.actualR < 0 }.reduce(0) { $0 + $1.actualR })
        guard losses > 0 else { return nil }
        return wins / losses
    }

    private var averageR: Double {
        closedTrades.isEmpty ? 0 : totalR / Double(closedTrades.count)
    }

    private var dayTotals: [(date: Date, r: Double)] {
        let grouped = Dictionary(grouping: closedTrades) { calendar.startOfDay(for: $0.tradingDay) }
        return grouped
            .map { key, items in (key, items.reduce(0) { $0 + $1.actualR }) }
            .sorted { $0.0 < $1.0 }
    }

    private var bestDay: (date: String, r: Double)? {
        guard let best = dayTotals.max(by: { $0.r < $1.r }) else { return nil }
        return (Fmt.shortDay(best.date), best.r)
    }

    private var worstDay: (date: String, r: Double)? {
        guard let worst = dayTotals.min(by: { $0.r < $1.r }) else { return nil }
        return (Fmt.shortDay(worst.date), worst.r)
    }

    private var periodOptions: [Date] {
        var set = Set<Date>()
        for cycle in cycles {
            if let start = interval(for: cycle.day)?.start {
                set.insert(start)
            }
        }
        for trade in trades {
            if let start = interval(for: trade.tradingDay)?.start {
                set.insert(start)
            }
        }
        if let start = interval(for: .now)?.start {
            set.insert(start)
        }
        return set.sorted(by: >)
    }

    // MARK: - Titles

    private var periodTitle: String {
        title(for: currentInterval)
    }

    private var previousTitle: String {
        title(for: previousInterval)
    }

    private func title(for interval: DateInterval?) -> String {
        guard let interval else { return "—" }
        switch period {
        case .month:
            return Fmt.monthYear(interval.start)
        case .year:
            return String(calendar.component(.year, from: interval.start))
        case .week:
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let startMonth = calendar.component(.month, from: interval.start)
            let endMonth = calendar.component(.month, from: end)
            if startMonth == endMonth {
                let startDay = calendar.component(.day, from: interval.start)
                return "\(startDay) — \(Fmt.shortDay(end))"
            }
            return "\(Fmt.shortDay(interval.start)) — \(Fmt.shortDay(end))"
        }
    }

    private var listTitle: String {
        switch period {
        case .month: return "Сделки месяца"
        case .week: return "Сделки недели"
        case .year: return "Сделки года"
        }
    }

    private var noPreviousText: String {
        switch period {
        case .month: return "Нет данных за прошлый месяц"
        case .week: return "Нет данных за прошлую неделю"
        case .year: return "Нет данных за прошлый год"
        }
    }

    private var pdfReportData: ReportPDFData {
        ReportPDFData(
            monthTitle: periodTitle,
            totalR: totalR,
            winRate: winRate,
            profitFactor: profitFactor,
            averageR: averageR,
            tradingDays: periodCycles.count,
            tradesCount: periodTrades.count,
            bestDay: bestDay,
            worstDay: worstDay,
            rows: periodTrades.map { trade in
                ReportPDFData.Row(
                    symbol: trade.symbol,
                    direction: trade.direction.rawValue,
                    day: Fmt.shortDay(trade.tradingDay),
                    result: resultTitle(trade.result),
                    r: trade.result == .open ? 0 : trade.actualR
                )
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)

                    GlassSegmented(
                        options: ReportPeriod.allCases,
                        selection: $period,
                        label: { $0.rawValue },
                        tint: { _ in Theme.accent }
                    )
                    .reveal(.blur, 1)

                    periodRow
                        .reveal(.rise, 2)
                    summaryCard
                        .reveal(.zoom, 3)
                    daysRow
                        .reveal(.rise, 4)
                    comparisonCard
                        .reveal(.rise, 5)

                    Text(listTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 4)

                    if periodTrades.isEmpty {
                        Text("Сделок за этот период нет")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .glassCard(cornerRadius: 18)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(periodTrades) { trade in
                                tradeRow(trade)
                            }
                        }
                    }

                    PrimaryButton(title: "Поделиться PDF", icon: "square.and.arrow.up") {
                        sharePDF()
                    }
                    .padding(.top, 6)

                    Text("Данные только из этого устройства")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
        .onChange(of: period) { _, _ in
            anchor = .now
        }
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .glassCircle()
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Итоги")
            ScreenTitle(text: "Отчёт")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(periodOptions, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            anchor = option
                        }
                        Haptics.select()
                    } label: {
                        if isSelected(option) {
                            Label(title(for: interval(for: option)), systemImage: "checkmark")
                        } else {
                            Text(title(for: interval(for: option)))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(periodTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }

            Spacer(minLength: 8)

            Button {
                sharePDF()
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .glassCircle()
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func isSelected(_ option: Date) -> Bool {
        guard let current = currentInterval,
              let candidate = interval(for: option) else {
            return false
        }
        return calendar.isDate(candidate.start, equalTo: current.start, toGranularity: period.component)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Суммарный R")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.r(totalR))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rColor(totalR))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(Fmt.tradingDays(periodCycles.count)) · \(Fmt.deals(periodTrades.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                summaryStat("Win rate", "\(Int((winRate * 100).rounded()))%", tint: Theme.textPrimary)
                summaryStat("Profit factor", profitFactor.map { String(format: "%.1f", $0) } ?? "—", tint: Theme.textPrimary)
                summaryStat("Средний R", Fmt.signed(averageR, digits: 2), tint: rColor(averageR))
            }
            .frame(width: 128, alignment: .leading)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func summaryStat(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var daysRow: some View {
        HStack(spacing: 10) {
            dayCard("Лучший день", bestDay, tint: Theme.green)
            dayCard("Худший день", worstDay, tint: Theme.red)
        }
    }

    private func dayCard(_ title: String, _ day: (date: String, r: Double)?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Text(day.map { Fmt.r($0.r) } ?? "—")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(day == nil ? Theme.textTertiary : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(day?.date ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        let current = stat(for: currentInterval)
        let previous = stat(for: previousInterval)
        let maxMagnitude = max(abs(current.totalR), abs(previous.totalR), 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("СРАВНЕНИЕ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .top, spacing: 12) {
                periodColumn(
                    title: periodTitle,
                    stat: current,
                    fraction: abs(current.totalR) / maxMagnitude,
                    emphasized: true
                )
                periodColumn(
                    title: previousTitle,
                    stat: previous,
                    fraction: abs(previous.totalR) / maxMagnitude,
                    emphasized: false
                )
            }

            if previous.hasData {
                Divider()
                    .overlay(Theme.hairline)

                deltaRow(
                    title: "Разница по R",
                    value: Fmt.signed(current.totalR - previous.totalR, digits: 1) + "R",
                    tint: rColor(current.totalR - previous.totalR)
                )

                deltaRow(
                    title: "Разница по win rate",
                    value: signedPoints(current.winRate - previous.winRate),
                    tint: percentColor(current.winRate - previous.winRate)
                )
            } else {
                Text(noPreviousText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func periodColumn(
        title: String,
        stat: PeriodStat,
        fraction: Double,
        emphasized: Bool
    ) -> some View {
        let tint = rColor(stat.totalR)
        let barHeight = stat.hasData ? max(CGFloat(fraction) * 54, 6) : 3

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(emphasized ? Theme.textSecondary : Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 10) {
                Text(stat.hasData ? Fmt.r(stat.totalR) : "—")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(stat.hasData ? tint : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                Capsule()
                    .fill(stat.hasData ? tint.opacity(emphasized ? 0.95 : 0.5) : Color.white.opacity(0.10))
                    .frame(width: 22, height: barHeight)
            }
            .frame(height: 70, alignment: .bottom)

            Text(summaryLine(stat))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(emphasized ? 0.06 : 0.03))
        )
    }

    private func summaryLine(_ stat: PeriodStat) -> String {
        guard stat.hasData else { return "Нет данных" }
        let percent = "\(Int((stat.winRate * 100).rounded()))%"
        return "\(percent) · \(Fmt.deals(stat.trades)) · \(Fmt.tradingDays(stat.days))"
    }

    private func deltaRow(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    private func signedPoints(_ delta: Double) -> String {
        let points = Int((delta * 100).rounded())
        guard points != 0 else { return "0 п.п." }
        let sign = points > 0 ? "+" : "\u{2212}"
        return "\(sign)\(abs(points)) п.п."
    }

    private func percentColor(_ delta: Double) -> Color {
        if delta > 0.005 { return Theme.green }
        if delta < -0.005 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Rows

    private func tradeRow(_ trade: Trade) -> some View {
        Button {
            selectedTrade = trade
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(trade.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(trade.direction.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                            )
                    }
                    (
                        Text("\(Fmt.shortDay(trade.tradingDay)) · ")
                        + Text(trade.result == .open ? "открыта" : Fmt.r(trade.actualR))
                            .foregroundColor(trade.result == .open ? Theme.accent : rColor(trade.actualR))
                    )
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func sharePDF() {
        guard let url = ReportPDF.make(pdfReportData) else {
            Haptics.warning()
            SharePresenter.presentFailure()
            return
        }
        SharePresenter.share([url])
        Haptics.success()
    }

    private func resultTitle(_ result: TradeResult) -> String {
        switch result {
        case .open: return "Открыта"
        case .tp: return "TP"
        case .sl: return "SL"
        case .be: return "BE"
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

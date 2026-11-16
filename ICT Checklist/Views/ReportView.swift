//
//  ReportView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var trades: [Trade]
    @Query private var cycles: [TradingCycle]

    @State private var monthAnchor: Date = ReportView.monthStart(.now)
    @State private var shareItems: [URL] = []
    @State private var showShare = false

    private var calendar: Calendar { Calendar.current }

    // MARK: - Data

    private var monthCycles: [TradingCycle] {
        cycles.filter { calendar.isDate($0.day, equalTo: monthAnchor, toGranularity: .month) }
    }

    private var monthTrades: [Trade] {
        trades
            .filter { calendar.isDate($0.tradingDay, equalTo: monthAnchor, toGranularity: .month) }
            .sorted { first, second in
                if first.tradingDay != second.tradingDay { return first.tradingDay > second.tradingDay }
                return first.entryDate > second.entryDate
            }
    }

    private var closedTrades: [Trade] {
        monthTrades.filter { $0.result != .open }
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

    private var monthOptions: [Date] {
        var set = Set<Date>()
        for cycle in cycles {
            set.insert(Self.monthStart(cycle.day))
        }
        for trade in trades {
            set.insert(Self.monthStart(trade.tradingDay))
        }
        set.insert(Self.monthStart(.now))
        return set.sorted(by: >)
    }

    private var pdfReportData: ReportPDFData {
        ReportPDFData(
            monthTitle: Fmt.monthYear(monthAnchor),
            totalR: totalR,
            winRate: winRate,
            profitFactor: profitFactor,
            averageR: averageR,
            tradingDays: monthCycles.count,
            tradesCount: monthTrades.count,
            bestDay: bestDay,
            worstDay: worstDay,
            rows: monthTrades.map { trade in
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
                    header
                    monthRow
                    summaryCard
                    daysRow

                    Text("Сделки месяца")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 4)

                    if monthTrades.isEmpty {
                        Text("Сделок за этот месяц нет")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .glassCard(cornerRadius: 18)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(monthTrades) { trade in
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
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
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
                .background(Circle().fill(Color.white.opacity(0.07)))
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

    private var monthRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(monthOptions, id: \.self) { month in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            monthAnchor = month
                        }
                        Haptics.select()
                    } label: {
                        if calendar.isDate(month, equalTo: monthAnchor, toGranularity: .month) {
                            Label(Fmt.monthYear(month), systemImage: "checkmark")
                        } else {
                            Text(Fmt.monthYear(month))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(Fmt.monthYear(monthAnchor))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
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
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
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
                Text("\(Fmt.tradingDays(monthCycles.count)) · \(Fmt.deals(monthTrades.count))")
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

    // MARK: - Rows

    private func tradeRow(_ trade: Trade) -> some View {
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
    }

    // MARK: - Actions

    private func sharePDF() {
        guard let url = ReportPDF.make(pdfReportData) else {
            Haptics.warning()
            return
        }
        shareItems = [url]
        showShare = true
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

    private static func monthStart(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

//
//  DayReviewView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct DayReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var trades: [Trade]
    @Query private var cycles: [TradingCycle]
    @Query private var plans: [TradePlan]
    @Query private var journalEntries: [JournalEntry]

    @State private var day: Date
    @State private var activeTrade: Trade?
    @State private var shareItems: [URL] = []
    @State private var showShare = false

    init(day: Date = .now) {
        let start = Calendar.current.startOfDay(for: day)
        _day = State(initialValue: start)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    // MARK: - Data

    private var dayTrades: [Trade] {
        trades
            .filter { calendar.isDate($0.tradingDay, inSameDayAs: day) }
            .sorted { $0.entryDate < $1.entryDate }
    }

    private var cycle: TradingCycle? {
        cycles
            .filter { calendar.isDate($0.day, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
            .last
    }

    private var plan: TradePlan? {
        plans
            .filter { calendar.isDate($0.day, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
            .last
    }

    private var journal: JournalEntry? {
        journalEntries.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    private var closedTrades: [Trade] {
        dayTrades.filter { $0.result != .open }
    }

    private var dayR: Double {
        closedTrades.reduce(0) { $0 + $1.actualR }
    }

    private var tpCount: Int { dayTrades.filter { $0.result == .tp }.count }
    private var slCount: Int { dayTrades.filter { $0.result == .sl }.count }
    private var beCount: Int { dayTrades.filter { $0.result == .be }.count }

    private var winRate: Double {
        closedTrades.isEmpty ? 0 : Double(tpCount) / Double(closedTrades.count)
    }

    private var keyLevels: [KeyLevel] {
        (cycle?.keyLevels ?? []).sorted { $0.price > $1.price }
    }

    private var hasCore: Bool {
        cycle != nil || plan != nil || !dayTrades.isEmpty
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    private var dayTitle: String {
        "\(Fmt.weekday(day)), \(Fmt.shortDay(day).lowercased())"
    }

    private var weekRangeText: String {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: day),
              let end = calendar.date(byAdding: .day, value: -1, to: week.end) else {
            return ""
        }
        return "неделя \(Fmt.dayMonth(week.start))–\(Fmt.dayMonth(end))"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .reveal(.slideLeft)
                    if !hasCore {
                        Text("Нет данных для экспорта")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                            .reveal(.blur, 1)
                    }
                    dayNav
                        .reveal(.drop, 1)

                    if !hasCore {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        summaryCard
                            .reveal(.zoom, 2)

                        if let plan {
                            planCard(plan)
                                .reveal(.rise, 3)
                        }

                        if let cycle {
                            cycleCard(cycle)
                                .reveal(.rise, 4)
                            if !keyLevels.isEmpty {
                                levelsCard(keyLevels)
                                    .reveal(.rise, 5)
                            }
                        }

                        if !dayTrades.isEmpty {
                            tradesCard
                                .reveal(.rise, 6)
                        }

                        if let journal {
                            journalCard(journal)
                                .reveal(.rise, 7)
                        }
                    }

                    Text("Разбор ничего не меняет в данных")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .animation(Theme.snappy, value: day)
            }
        }
        .fullScreenCover(item: $activeTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Разбор")
                ScreenTitle(text: "Разбор дня")
            }

            Spacer(minLength: 8)

            Button {
                exportPDF()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                    Text("PDF")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hasCore ? Theme.textPrimary : Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!hasCore)
        }
    }

    private func exportPDF() {
        guard hasCore else {
            Haptics.warning()
            return
        }

        var sections: [DayReviewPDFData.Section] = []

        if let plan {
            sections.append(
                DayReviewPDFData.Section(
                    title: "План дня",
                    rows: [
                        DayReviewPDFData.Row(title: "Результат", value: plan.result.rawValue),
                        DayReviewPDFData.Row(
                            title: "Чек-лист",
                            value: "\(plan.checkedCount) из \(PlanCheck.allCases.count)"
                        )
                    ]
                )
            )
        }

        if let cycle {
            sections.append(
                DayReviewPDFData.Section(
                    title: "Цикл",
                    rows: [
                        DayReviewPDFData.Row(title: "Направление", value: cycle.direction.rawValue),
                        DayReviewPDFData.Row(title: "Зона", value: cycle.zone?.rawValue ?? "—"),
                        DayReviewPDFData.Row(title: "Point A", value: Fmt.price(cycle.pointAPrice)),
                        DayReviewPDFData.Row(title: "Point B", value: Fmt.price(cycle.pointBPrice)),
                        DayReviewPDFData.Row(
                            title: "Подтверждения",
                            value: "\(cycle.confirmations.count) из \(ConfirmationKey.allCases.count)"
                        ),
                        DayReviewPDFData.Row(title: "STOP DAY", value: cycle.stopDay ? "Да" : "Нет")
                    ]
                )
            )
        }

        if !keyLevels.isEmpty {
            sections.append(
                DayReviewPDFData.Section(
                    title: "Ключевые уровни",
                    rows: keyLevels.map { level in
                        DayReviewPDFData.Row(
                            title: "\(level.type.rawValue)   \(Fmt.price(level.price))",
                            value: level.absorbed ? "поглощён" : "активен"
                        )
                    }
                )
            )
        }

        let data = DayReviewPDFData(
            dayTitle: dayTitle,
            weekTitle: weekRangeText,
            dayR: dayR,
            hasResult: !closedTrades.isEmpty,
            tradesCount: dayTrades.count,
            winRate: winRate,
            tp: tpCount,
            sl: slCount,
            be: beCount,
            sections: sections,
            trades: dayTrades.map { trade in
                DayReviewPDFData.TradeRow(
                    symbol: trade.symbol,
                    direction: trade.direction.rawValue,
                    result: trade.result == .open ? "открыта" : trade.result.rawValue,
                    r: trade.actualR
                )
            },
            journalMood: journal?.mood.rawValue,
            journalNote: journal?.note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard let url = DayReviewPDF.make(data) else {
            Haptics.warning()
            return
        }

        shareItems = [url]
        showShare = true
        Haptics.success()
    }

    private var dayNav: some View {
        HStack(spacing: 10) {
            navButton(icon: "chevron.left") {
                shift(-1)
            }

            VStack(spacing: 2) {
                Text(dayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(weekRangeText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            navButton(icon: "chevron.right") {
                shift(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 18)
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func shift(_ days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: day) else { return }
        withAnimation(Theme.snappy) {
            day = calendar.startOfDay(for: next)
        }
        Haptics.select()
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Итог дня")

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(closedTrades.isEmpty ? "—" : Fmt.r(dayR))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(closedTrades.isEmpty ? Theme.textTertiary : rColor(dayR))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 8)

                Text("\(dayTrades.count) \(Fmt.dealWord(dayTrades.count)) · \(Int((winRate * 100).rounded()))% win rate")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 8) {
                pill("TP \(tpCount)", tint: Theme.green)
                pill("SL \(slCount)", tint: Theme.red)
                pill("BE \(beCount)", tint: Theme.textSecondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func pill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    // MARK: - Plan

    private func planCard(_ plan: TradePlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "План дня")
                .padding(.bottom, 10)

            infoRow(
                "Результат",
                plan.result.rawValue,
                tint: planResultTint(plan.result)
            )
            divider
            infoRow(
                "Чек-лист",
                "\(plan.checkedCount) из \(PlanCheck.allCases.count)"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func planResultTint(_ result: PlanResult) -> Color {
        switch result {
        case .win: return Theme.green
        case .loss: return Theme.red
        case .be, .skip: return Theme.textSecondary
        case .noTrade: return Theme.textTertiary
        case .pending: return Theme.textSecondary
        }
    }

    // MARK: - Cycle

    private func cycleCard(_ cycle: TradingCycle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Цикл")
                .padding(.bottom, 10)

            infoRow(
                "Направление",
                cycle.direction.rawValue,
                tint: cycle.direction == .long ? Theme.green : Theme.red
            )
            divider
            infoRow("Зона", cycle.zone?.rawValue ?? "—")
            divider
            infoRow("Point A", Fmt.price(cycle.pointAPrice))
            divider
            infoRow("Point B", Fmt.price(cycle.pointBPrice))
            divider
            infoRow("Подтверждения", "\(cycle.confirmations.count) из \(ConfirmationKey.allCases.count)")
            divider
            infoRow(
                "STOP DAY",
                cycle.stopDay ? "Да" : "Нет",
                tint: cycle.stopDay ? Theme.red : Theme.textPrimary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Key levels

    private func levelsCard(_ levels: [KeyLevel]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Ключевые уровни")
                .padding(.bottom, 10)

            ForEach(Array(levels.enumerated()), id: \.element.persistentModelID) { index, level in
                if index > 0 {
                    divider
                }
                HStack(spacing: 8) {
                    Text(level.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Fmt.price(level.price))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .frame(minWidth: 70, alignment: .trailing)

                    Text(level.absorbed ? "поглощён" : "активен")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(level.absorbed ? Theme.red : Theme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill((level.absorbed ? Theme.red : Theme.green).opacity(0.16)))
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Trades

    private var tradesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Сделки дня")
                .padding(.bottom, 8)

            ForEach(Array(dayTrades.enumerated()), id: \.element.persistentModelID) { index, trade in
                if index > 0 {
                    divider
                }
                tradeRow(trade)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func tradeRow(_ trade: Trade) -> some View {
        Button {
            activeTrade = trade
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Text(trade.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 6)

                Text(trade.direction.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)

                Text(trade.result.rawValue)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(resultTint(trade))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(resultTint(trade).opacity(0.16)))

                Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(trade.result == .open ? Theme.textTertiary : rColor(trade.actualR))
                    .frame(minWidth: 52, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resultTint(_ trade: Trade) -> Color {
        switch trade.result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.textSecondary
        case .open: return Theme.textTertiary
        }
    }

    // MARK: - Journal

    private func journalCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Дневник")

            HStack(spacing: 8) {
                Text("Настроение")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(entry.mood.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            let note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                Divider()
                    .overlay(Theme.hairline)
                Text(note)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("За этот день данных нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Проведите цикл, заполните план дня или закройте сделку — здесь появится разбор.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Rows

    private var divider: some View {
        Divider()
            .overlay(Theme.hairline)
    }

    private func infoRow(_ title: String, _ value: String, tint: Color = Theme.textPrimary) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 9)
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

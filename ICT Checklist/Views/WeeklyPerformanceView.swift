//
//  WeeklyPerformanceView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

private enum ReviewTile: String, CaseIterable, Identifiable {
    case missed
    case execution
    case winRate
    case planOutcome
    case compliance
    case potentialR
    case gainedR
    case averageR
    case profitableDays
    case realisedPnL
    case averagePnL

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missed: return "Пропущенные сделки"
        case .execution: return "Коэффициент исполнения"
        case .winRate: return "Win rate"
        case .planOutcome: return "План и итог"
        case .compliance: return "Соблюдение плана"
        case .potentialR: return "Потенциальный RR"
        case .gainedR: return "Полученный RR"
        case .averageR: return "Средний RR"
        case .profitableDays: return "Прибыльность дней"
        case .realisedPnL: return "Реализованный P&L"
        case .averagePnL: return "Средний P&L"
        }
    }
}

struct WeeklyPerformanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var trades: [Trade]
    @Query private var tradePlans: [TradePlan]
    @Query private var cycles: [TradingCycle]
    @Query private var journalEntries: [JournalEntry]
    @Query private var weekPlanList: [WeekPlan]
    @Query private var settingsList: [AppSettings]

    @State private var weekStart: Date = WeeklyPerformanceView.currentWeekStart()
    @State private var activeTrade: Trade?
    @State private var compareWithPrevious = false
    @State private var shareItems: [URL] = []
    @State private var showShare = false
    @State private var isEditingReview = false
    @State private var reviewDraft = ""
    @State private var showTiles = false

    // MARK: - Week range

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var weekEnd: Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    private var isCurrentWeek: Bool {
        weekStart == Self.currentWeekStart()
    }

    static func currentWeekStart() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        return cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    private func contains(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= weekStart && day < weekEnd
    }

    private func inRange(_ date: Date, start: Date) -> Bool {
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
        let day = calendar.startOfDay(for: date)
        return day >= start && day < end
    }

    private func shift(_ weeks: Int) {
        guard let next = calendar.date(byAdding: .day, value: 7 * weeks, to: weekStart) else { return }
        withAnimation(Theme.snappy) {
            weekStart = next
        }
        Haptics.select()
    }

    private var canGoNext: Bool {
        guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return false }
        return next <= Self.currentWeekStart()
    }

    private var weekTitle: String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd
        return "\(Fmt.dayMonth(weekStart)) — \(Fmt.dayMonth(lastDay))"
    }

    private var weekCaption: String {
        if isCurrentWeek { return "Текущая неделя" }
        return Fmt.monthYear(weekStart)
    }

    // MARK: - Data

    private var weekTrades: [Trade] {
        trades
            .filter { contains($0.tradingDay) }
            .sorted { $0.entryDate < $1.entryDate }
    }

    private var closedTrades: [Trade] {
        weekTrades.filter { $0.result != .open }
    }

    private var weekPlans: [TradePlan] {
        tradePlans.filter { contains($0.day) }
    }

    private var weekCycles: [TradingCycle] {
        cycles.filter { contains($0.day) }
    }

    private var weekJournals: [JournalEntry] {
        journalEntries
            .filter { contains($0.day) }
            .sorted { $0.day > $1.day }
    }

    private var weekRecord: WeekPlan? {
        weekPlanList.first { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    // MARK: - Metrics

    private var tpCount: Int { closedTrades.filter { $0.result == .tp }.count }
    private var slCount: Int { closedTrades.filter { $0.result == .sl }.count }
    private var beCount: Int { closedTrades.filter { $0.result == .be }.count }

    private var winRate: Double {
        closedTrades.isEmpty ? 0 : Double(tpCount) / Double(closedTrades.count)
    }

    private var gainedR: Double {
        closedTrades.reduce(0) { $0 + $1.actualR }
    }

    private var potentialR: Double {
        closedTrades.reduce(0) { $0 + $1.plannedRR }
    }

    private var averageR: Double {
        closedTrades.isEmpty ? 0 : gainedR / Double(closedTrades.count)
    }

    private var realisedPnL: Double {
        closedTrades.reduce(0) { $0 + $1.actualR * $1.riskUSD }
    }

    private var averagePnL: Double {
        closedTrades.isEmpty ? 0 : realisedPnL / Double(closedTrades.count)
    }

    private var decidedPlans: [TradePlan] {
        weekPlans.filter { $0.result == .win || $0.result == .loss || $0.result == .be }
    }

    private var plansWithResult: [TradePlan] {
        weekPlans.filter { $0.result != .pending }
    }

    private var executionRate: Double? {
        guard !plansWithResult.isEmpty else { return nil }
        return Double(decidedPlans.count) / Double(plansWithResult.count)
    }

    private var complianceRate: Double? {
        guard !decidedPlans.isEmpty else { return nil }
        let complete = decidedPlans.filter { $0.isChecklistComplete }.count
        return Double(complete) / Double(decidedPlans.count)
    }

    private var planOutcomeRate: Double? {
        guard !closedTrades.isEmpty else { return nil }
        let full = closedTrades.filter { trade in
            guard let cycle = trade.cycle else { return false }
            return cycle.confirmations.count == ConfirmationKey.allCases.count
        }.count
        return Double(full) / Double(closedTrades.count)
    }

    private var missedTrades: Int {
        var days = Set<Date>()
        for plan in weekPlans where plan.result == .skip || plan.result == .noTrade {
            days.insert(calendar.startOfDay(for: plan.day))
        }
        for cycle in weekCycles where cycle.trade == nil && cycle.result == .stopped {
            days.insert(calendar.startOfDay(for: cycle.day))
        }
        return days.count
    }

    private var dayTotals: [(day: Date, r: Double)] {
        var map: [Date: Double] = [:]
        for trade in closedTrades {
            let day = calendar.startOfDay(for: trade.tradingDay)
            map[day, default: 0] += trade.actualR
        }
        return map.map { (day: $0.key, r: $0.value) }.sorted { $0.day < $1.day }
    }

    private var profitableDaysRate: Double? {
        let totals = dayTotals
        guard !totals.isEmpty else { return nil }
        return Double(totals.filter { $0.r > 0.05 }.count) / Double(totals.count)
    }

    private var bestDay: (day: Date, r: Double)? {
        dayTotals.max { $0.r < $1.r }
    }

    private var worstDay: (day: Date, r: Double)? {
        dayTotals.min { $0.r < $1.r }
    }

    private var hasAnyData: Bool {
        !closedTrades.isEmpty || !plansWithResult.isEmpty || !weekCycles.isEmpty
    }

    // MARK: - Comparison with the previous week

    private struct WeekComparison {
        var closedCount = 0
        var gainedR: Double = 0
        var winRate: Double = 0
        var averageR: Double = 0
        var realisedPnL: Double = 0
        var missed = 0
        var executionRate: Double?
        var complianceRate: Double?
        var hasData = false
    }

    private var previousWeekStart: Date {
        calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
    }

    private var previousWeek: WeekComparison {
        let start = previousWeekStart
        let weekTrades = trades.filter { inRange($0.tradingDay, start: start) }
        let closed = weekTrades.filter { $0.result != .open }
        let weekPlans = tradePlans.filter { inRange($0.day, start: start) }
        let weekCycles = cycles.filter { inRange($0.day, start: start) }

        var result = WeekComparison()
        result.closedCount = closed.count
        result.gainedR = closed.reduce(0) { $0 + $1.actualR }
        result.averageR = closed.isEmpty ? 0 : result.gainedR / Double(closed.count)
        result.realisedPnL = closed.reduce(0) { $0 + $1.actualR * $1.riskUSD }
        result.winRate = closed.isEmpty
            ? 0
            : Double(closed.filter { $0.result == .tp }.count) / Double(closed.count)

        var missedDays = Set<Date>()
        for plan in weekPlans where plan.result == .skip || plan.result == .noTrade {
            missedDays.insert(calendar.startOfDay(for: plan.day))
        }
        for cycle in weekCycles where cycle.trade == nil && cycle.result == .stopped {
            missedDays.insert(calendar.startOfDay(for: cycle.day))
        }
        result.missed = missedDays.count

        let decided = weekPlans.filter { $0.result == .win || $0.result == .loss || $0.result == .be }
        let withResult = weekPlans.filter { $0.result != .pending }
        if !withResult.isEmpty {
            result.executionRate = Double(decided.count) / Double(withResult.count)
        }
        if !decided.isEmpty {
            result.complianceRate = Double(decided.filter { $0.isChecklistComplete }.count) / Double(decided.count)
        }

        result.hasData = !closed.isEmpty || !withResult.isEmpty || !weekCycles.isEmpty
        return result
    }

    /// Значения прошлой недели — только когда переключатель включён и за неё есть данные.
    private var previousComparison: WeekComparison? {
        guard compareWithPrevious else { return nil }
        let previous = previousWeek
        return previous.hasData ? previous : nil
    }

    private func previousLine(_ previous: String, _ delta: String) -> String {
        "пр. \(previous) · \(delta)"
    }

    private func deltaR(_ current: Double, _ previous: Double) -> String {
        Fmt.r(current - previous)
    }

    private func deltaPercent(_ current: Double, _ previous: Double) -> String {
        let points = ((current - previous) * 100).rounded()
        if abs(points) < 1 { return "0 п.п." }
        let sign = points > 0 ? "+" : "\u{2212}"
        return "\(sign)\(Int(abs(points))) п.п."
    }

    private func deltaCount(_ current: Int, _ previous: Int) -> String {
        let difference = current - previous
        if difference == 0 { return "0" }
        return (difference > 0 ? "+" : "\u{2212}") + "\(abs(difference))"
    }

    private func comparisonTint(_ current: Double, _ previous: Double) -> Color {
        let difference = current - previous
        if difference > 0.0001 { return Theme.green }
        if difference < -0.0001 { return Theme.red }
        return Theme.textSecondary
    }

    private func comparisonTint(_ current: Int, _ previous: Int, lowerIsBetter: Bool) -> Color {
        let difference = current - previous
        if difference == 0 { return Theme.textSecondary }
        let better = lowerIsBetter ? difference < 0 : difference > 0
        return better ? Theme.green : Theme.red
    }

    private func rSentence(_ previous: WeekComparison) -> String {
        let difference = gainedR - previous.gainedR
        if abs(difference) < 0.05 { return "По R — как на прошлой неделе" }
        if difference > 0 { return "Лучше прошлой недели на \(Fmt.r(difference))" }
        return "Хуже прошлой недели на \(Fmt.r(abs(difference)))"
    }

    private func winRateSentence(_ previous: WeekComparison) -> String {
        let difference = (winRate - previous.winRate) * 100
        if abs(difference) < 1 { return "Win rate не изменился" }
        let points = Int(abs(difference).rounded())
        return difference > 0
            ? "Win rate выше прошлой недели на \(points) п.п."
            : "Win rate ниже прошлой недели на \(points) п.п."
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .reveal(.slideLeft)
                    if !hasAnyData {
                        Text("Нет данных для экспорта")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                            .reveal(.blur, 1)
                    }
                    weekNav
                        .reveal(.drop, 1)
                    weekReviewCard
                        .reveal(.rise, 1)
                    compareToggle
                        .reveal(.rise, 1)

                    if !hasAnyData {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        heroCard
                            .reveal(.zoom, 2)
                        metricsGrid
                            .reveal(.rise, 3)
                        if compareWithPrevious {
                            comparisonSummaryCard
                                .reveal(.rise, 4)
                        }
                    }

                    if let weekRecord {
                        weekPlanCard(weekRecord)
                            .reveal(.rise, 4)
                    }

                    if !weekJournals.isEmpty {
                        journalCard
                            .reveal(.rise, 5)
                    }

                    if !weekTrades.isEmpty {
                        tradesCard
                            .reveal(.rise, 6)
                    }

                    Text("Разбор собирается из сделок, планов, циклов и дневника. Ничего не создаётся и не меняется.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .animation(Theme.snappy, value: weekStart)
            }
        }
        .fullScreenCover(item: $activeTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showTiles) {
            tilesSheet
        }
        .onChange(of: weekStart) { _, _ in
            isEditingReview = false
            reviewDraft = ""
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
                SectionLabel(text: "Weekly performance")
                ScreenTitle(text: "Разбор недели")
            }

            Spacer(minLength: 8)

            Button {
                showTiles = true
                Haptics.tap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Блоки")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                exportPDF()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                    Text("PDF")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hasAnyData ? Theme.textPrimary : Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!hasAnyData)
        }
    }

    private func exportPDF() {
        guard hasAnyData else {
            Haptics.warning()
            return
        }

        let previous = previousComparison

        var metrics: [WeeklyPDFData.Metric] = [
            WeeklyPDFData.Metric(
                title: "Всего сделок",
                value: "\(weekTrades.count)",
                comparison: nil
            )
        ]

        if isVisible(.missed) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Пропущенные сделки",
                    value: "\(missedTrades)",
                    comparison: previous.map {
                        previousLine("\($0.missed)", deltaCount(missedTrades, $0.missed))
                    }
                )
            )
        }
        if isVisible(.execution) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Коэффициент исполнения",
                    value: executionRate.map(percentText) ?? "—",
                    comparison: previous.map {
                        previousLine(
                            percentText($0.executionRate ?? 0),
                            deltaPercent(executionRate ?? 0, $0.executionRate ?? 0)
                        )
                    }
                )
            )
        }
        if isVisible(.winRate) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Win rate",
                    value: closedTrades.isEmpty ? "—" : percentText(winRate),
                    comparison: previous.map {
                        previousLine(percentText($0.winRate), deltaPercent(winRate, $0.winRate))
                    }
                )
            )
        }
        if isVisible(.planOutcome) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "План и итог",
                    value: planOutcomeRate.map(percentText) ?? "—",
                    comparison: nil
                )
            )
        }
        if isVisible(.compliance) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Соблюдение плана",
                    value: complianceRate.map(percentText) ?? "—",
                    comparison: previous.map {
                        previousLine(
                            percentText($0.complianceRate ?? 0),
                            deltaPercent(complianceRate ?? 0, $0.complianceRate ?? 0)
                        )
                    }
                )
            )
        }
        if isVisible(.potentialR) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Потенциальный RR",
                    value: Fmt.r(potentialR),
                    comparison: nil
                )
            )
        }
        if isVisible(.gainedR) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Полученный RR",
                    value: Fmt.r(gainedR),
                    comparison: previous.map {
                        previousLine(Fmt.r($0.gainedR), deltaR(gainedR, $0.gainedR))
                    }
                )
            )
        }
        if isVisible(.averageR) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Средний RR",
                    value: closedTrades.isEmpty ? "—" : Fmt.r(averageR),
                    comparison: previous.map {
                        previousLine(Fmt.r($0.averageR), deltaR(averageR, $0.averageR))
                    }
                )
            )
        }
        if isVisible(.profitableDays) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Прибыльность дней",
                    value: profitableDaysRate.map(percentText) ?? "—",
                    comparison: nil
                )
            )
        }
        if isVisible(.realisedPnL) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Реализованный P&L",
                    value: moneyText(realisedPnL),
                    comparison: previous.map {
                        previousLine(
                            moneyText($0.realisedPnL),
                            moneyText(realisedPnL - $0.realisedPnL)
                        )
                    }
                )
            )
        }
        if isVisible(.averagePnL) {
            metrics.append(
                WeeklyPDFData.Metric(
                    title: "Средний P&L",
                    value: closedTrades.isEmpty ? "—" : moneyText(averagePnL),
                    comparison: nil
                )
            )
        }

        let data = WeeklyPDFData(
            weekTitle: weekTitle,
            gainedR: gainedR,
            winRate: winRate,
            tradesCount: weekTrades.count,
            metrics: metrics,
            rows: weekTrades.map { trade in
                WeeklyPDFData.Row(
                    day: Fmt.shortDay(trade.tradingDay),
                    symbol: trade.symbol,
                    direction: trade.direction.rawValue,
                    result: trade.result == .open ? "открыта" : trade.result.rawValue,
                    r: trade.actualR
                )
            }
        )

        guard let url = WeeklyPDF.make(data) else {
            Haptics.warning()
            return
        }

        shareItems = [url]
        showShare = true
        Haptics.success()
    }

    private var weekNav: some View {
        HStack(spacing: 10) {
            navButton(icon: "chevron.left", enabled: true) {
                shift(-1)
            }

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(weekCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)

            navButton(icon: "chevron.right", enabled: canGoNext) {
                shift(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 18)
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? .white.opacity(0.85) : Theme.textTertiary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(enabled ? 0.08 : 0.03)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Итог недели")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.r(gainedR))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rColor(gainedR))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(closedTrades.count) \(Fmt.dealWord(closedTrades.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(Int((winRate * 100).rounded()))% win rate")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(dayTotals.count) \(tradingDaysWord(dayTotals.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            HStack(spacing: 6) {
                pill("TP \(tpCount)", tint: Theme.green)
                pill("SL \(slCount)", tint: Theme.red)
                pill("BE \(beCount)", tint: Theme.textSecondary)
                Spacer(minLength: 0)
            }

            if let bestDay, let worstDay, dayTotals.count > 1 {
                Text("Лучший день \(Fmt.weekday(bestDay.day)) \(Fmt.r(bestDay.r)) · худший \(Fmt.weekday(worstDay.day)) \(Fmt.r(worstDay.r))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func pill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func tradingDaysWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "торговых дней" }
        if mod10 == 1 { return "торговый день" }
        if mod10 >= 2 && mod10 <= 4 { return "торговых дня" }
        return "торговых дней"
    }

    // MARK: - Block settings

    private var settings: AppSettings? {
        settingsList.first
    }

    private var hiddenTiles: Set<String> {
        Set(
            (settings?.hiddenReviewTilesRaw ?? "")
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private func isVisible(_ tile: ReviewTile) -> Bool {
        !hiddenTiles.contains(tile.rawValue)
    }

    private func tileBinding(_ tile: ReviewTile) -> Binding<Bool> {
        Binding(
            get: { isVisible(tile) },
            set: { visible in
                var hidden = hiddenTiles
                if visible {
                    hidden.remove(tile.rawValue)
                } else {
                    hidden.insert(tile.rawValue)
                }
                setHiddenTiles(hidden)
            }
        )
    }

    private func setHiddenTiles(_ hidden: Set<String>) {
        settings?.hiddenReviewTilesRaw = hidden.sorted().joined(separator: ",")
        try? context.save()
    }

    private var tilesSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Блоки разбора")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    showTiles = false
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }

            Text("Скрытые плитки не показываются в разборе и не попадают в PDF.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(ReviewTile.allCases.enumerated()), id: \.element) { index, tile in
                        if index > 0 {
                            Divider()
                                .overlay(Theme.hairline)
                        }
                        ToggleRow(
                            title: tile.title,
                            isOn: tileBinding(tile)
                        )
                    }
                }
            }

            HStack(spacing: 0) {
                Button {
                    setHiddenTiles([])
                    Haptics.tap()
                } label: {
                    Text("Показать все")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    // MARK: - Metrics

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            metricCard(
                icon: "list.bullet.rectangle",
                title: "Всего сделок",
                value: "\(weekTrades.count)",
                caption: "закрыто \(closedTrades.count) · открыто \(weekTrades.count - closedTrades.count)",
                tint: Theme.textPrimary
            )
            metricCard(
                tile: .missed,
                icon: "arrow.uturn.left",
                title: "Пропущенные сделки",
                value: "\(missedTrades)",
                caption: "дни без входа по плану или сценарию",
                tint: Theme.textSecondary,
                comparison: previousComparison.map {
                    previousLine("\($0.missed)", deltaCount(missedTrades, $0.missed))
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(missedTrades, $0.missed, lowerIsBetter: true)
                }
            )
            metricCard(
                tile: .execution,
                icon: "play.fill",
                title: "Коэффициент исполнения",
                value: executionRate.map(percentText) ?? "—",
                caption: "\(decidedPlans.count) из \(plansWithResult.count) планов с итогом",
                tint: Theme.lavender,
                progress: executionRate,
                comparison: previousComparison.map {
                    previousLine(
                        percentText($0.executionRate ?? 0),
                        deltaPercent(executionRate ?? 0, $0.executionRate ?? 0)
                    )
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(executionRate ?? 0, $0.executionRate ?? 0)
                }
            )
            metricCard(
                tile: .winRate,
                icon: "trophy.fill",
                title: "Win rate",
                value: closedTrades.isEmpty ? "—" : percentText(winRate),
                caption: "\(tpCount) TP · \(slCount) SL · \(beCount) BE",
                tint: Theme.green,
                progress: closedTrades.isEmpty ? nil : winRate,
                comparison: previousComparison.map {
                    previousLine(percentText($0.winRate), deltaPercent(winRate, $0.winRate))
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(winRate, $0.winRate)
                }
            )
            metricCard(
                tile: .planOutcome,
                icon: "mappin.and.ellipse",
                title: "План и итог",
                value: planOutcomeRate.map(percentText) ?? "—",
                caption: "сделки с полной цепочкой подтверждений",
                tint: Theme.teal,
                progress: planOutcomeRate
            )
            metricCard(
                tile: .compliance,
                icon: "checkmark.seal.fill",
                title: "Соблюдение плана",
                value: complianceRate.map(percentText) ?? "—",
                caption: "полный чек-лист в решённых планах",
                tint: Theme.orange,
                progress: complianceRate,
                comparison: previousComparison.map {
                    previousLine(
                        percentText($0.complianceRate ?? 0),
                        deltaPercent(complianceRate ?? 0, $0.complianceRate ?? 0)
                    )
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(complianceRate ?? 0, $0.complianceRate ?? 0)
                }
            )
            metricCard(
                tile: .potentialR,
                icon: "scope",
                title: "Потенциальный RR",
                value: Fmt.r(potentialR),
                caption: "план по закрытым сделкам",
                tint: Theme.textSecondary
            )
            metricCard(
                tile: .gainedR,
                icon: "arrow.down.right",
                title: "Полученный RR",
                value: Fmt.r(gainedR),
                caption: "фактический результат недели",
                tint: rColor(gainedR),
                comparison: previousComparison.map {
                    previousLine(Fmt.r($0.gainedR), deltaR(gainedR, $0.gainedR))
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(gainedR, $0.gainedR)
                }
            )
            metricCard(
                tile: .averageR,
                icon: "arrow.left.and.right",
                title: "Средний RR",
                value: closedTrades.isEmpty ? "—" : Fmt.r(averageR),
                caption: "на одну закрытую сделку",
                tint: rColor(averageR),
                comparison: previousComparison.map {
                    previousLine(Fmt.r($0.averageR), deltaR(averageR, $0.averageR))
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(averageR, $0.averageR)
                }
            )
            metricCard(
                tile: .profitableDays,
                icon: "percent",
                title: "Прибыльность дней",
                value: profitableDaysRate.map(percentText) ?? "—",
                caption: "дни с положительным R",
                tint: Theme.green,
                progress: profitableDaysRate
            )
            metricCard(
                tile: .realisedPnL,
                icon: "banknote",
                title: "Реализованный P&L",
                value: moneyText(realisedPnL),
                caption: "R × риск в $ по сделкам",
                tint: realisedPnL < 0 ? Theme.red : Theme.green,
                comparison: previousComparison.map {
                    previousLine(
                        moneyText($0.realisedPnL),
                        moneyText(realisedPnL - $0.realisedPnL)
                    )
                },
                comparisonTint: previousComparison.map {
                    comparisonTint(realisedPnL, $0.realisedPnL)
                }
            )
            metricCard(
                tile: .averagePnL,
                icon: "equal.circle",
                title: "Средний P&L",
                value: closedTrades.isEmpty ? "—" : moneyText(averagePnL),
                caption: "на одну сделку",
                tint: averagePnL < 0 ? Theme.red : Theme.green
            )
        }
    }

    @ViewBuilder
    private func metricCard(
        tile: ReviewTile? = nil,
        icon: String,
        title: String,
        value: String,
        caption: String,
        tint: Color,
        progress: Double? = nil,
        comparison: String? = nil,
        comparisonTint: Color? = nil
    ) -> some View {
        if tile.map({ isVisible($0) }) ?? true {
            VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if let progress {
                progressBar(progress, tint: tint)
            }

            Text(caption)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let comparison {
                Text(comparison)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(comparisonTint ?? Theme.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Week review note

    private var savedReview: String {
        (weekRecord?.review ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var weekReviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Итог недели")

            if isEditingReview {
                TextField(
                    "Что сработало, что нет, что менять",
                    text: $reviewDraft,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    Button {
                        isEditingReview = false
                        reviewDraft = ""
                        Haptics.tap()
                    } label: {
                        Text("Отмена")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 8)

                    Button {
                        saveReview()
                    } label: {
                        Text("Сохранить итог")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            } else {
                Button {
                    reviewDraft = savedReview
                    isEditingReview = true
                    Haptics.tap()
                } label: {
                    Text(savedReview.isEmpty ? "Написать итог недели" : savedReview)
                        .font(.system(size: 13.5))
                        .foregroundStyle(savedReview.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func saveReview() {
        let text = reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let plan: WeekPlan
        if let existing = weekRecord {
            plan = existing
        } else {
            let created = WeekPlan(weekStart: weekStart)
            context.insert(created)
            plan = created
        }

        plan.review = text
        plan.updatedAt = .now
        try? context.save()

        isEditingReview = false
        reviewDraft = ""
        Haptics.success()
    }

    // MARK: - Compare toggle

    private var compareToggle: some View {
        Toggle(isOn: $compareWithPrevious.animation(Theme.snappy)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Сравнить с прошлой неделей")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Рядом с блоками — значения прошлой недели и разница")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var comparisonSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Сравнение недель")

            if let previous = previousComparison {
                Text(rSentence(previous))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(comparisonTint(gainedR, previous.gainedR))
                    .fixedSize(horizontal: false, vertical: true)

                Text(winRateSentence(previous))
                    .font(.system(size: 14))
                    .foregroundStyle(comparisonTint(winRate, previous.winRate))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Прошлая неделя: \(Fmt.r(previous.gainedR)) · \(percentText(previous.winRate)) win rate · \(previous.closedCount) \(Fmt.dealWord(previous.closedCount))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Нет данных за прошлую неделю")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func progressBar(_ value: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(tint.opacity(0.8))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func moneyText(_ value: Double) -> String {
        let sign = value < -0.005 ? "\u{2212}" : (value > 0.005 ? "+" : "")
        let magnitude = abs(value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = magnitude < 100 ? 2 : 0
        let text = formatter.string(from: NSNumber(value: magnitude)) ?? String(format: "%.2f", magnitude)
        return "\(sign)$\(text)"
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Week plan

    private func weekPlanCard(_ plan: WeekPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "План недели")
                Spacer(minLength: 8)
                Text("\(Fmt.r(gainedR)) из \(Fmt.r(plan.targetR))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(rColor(gainedR))
            }

            if !plan.theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(plan.theme)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Тема недели не задана")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            progressBar(plan.targetR > 0 ? max(0, min(1, gainedR / plan.targetR)) : 0, tint: rColor(gainedR))

            let scenarios = plan.sortedScenarios.filter {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !scenarios.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(scenarios) { scenario in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 3, height: 3)
                                .padding(.top, 6)
                            Text(scenario.title)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Journal

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Дневник недели")

            VStack(spacing: 8) {
                ForEach(weekJournals) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(Fmt.shortDay(entry.day))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 6)
                            Text(entry.mood.rawValue)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Text(entry.preview)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Trades

    private var tradesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Сделки недели")
                Spacer(minLength: 8)
                Text("\(weekTrades.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(weekTrades.enumerated()), id: \.element.persistentModelID) { index, trade in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.leading, 12)
                    }
                    tradeRow(trade)
                }
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
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trade.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.direction.rawValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(trade.result == .open ? "открыта" : trade.result.rawValue)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(resultTint(trade))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(resultTint(trade).opacity(0.12)))

                Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("За эту неделю пока нет данных")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Проведите цикл или план дня, закройте сделку — здесь появятся блоки недельного разбора.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}

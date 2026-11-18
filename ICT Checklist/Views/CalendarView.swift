//
//  CalendarView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

private struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let inMonth: Bool
    let cycle: TradingCycle?
}

private struct DayTarget: Identifiable {
    let day: Date

    var id: Date { day }
}

struct CalendarView: View {
    @Query private var cycles: [TradingCycle]
    @Query private var settingsList: [AppSettings]

    @State private var monthAnchor: Date = CalendarView.monthStart(.now)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var reviewTarget: DayTarget?

    @State private var news: [EconomicEvent] = []
    @State private var newsLoading = false
    @State private var newsError: String?
    @State private var onlyHighImpact = false
    @State private var newsUpdatedAt: Date?

    private static let weekdaySymbols = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var settings: AppSettings? { settingsList.first }

    private var cycleStartText: String {
        Fmt.clock(hour: settings?.cycleStartHour ?? 19, minute: settings?.cycleStartMinute ?? 0)
    }

    private var cycleEndText: String {
        Fmt.clock(hour: settings?.cycleEndHour ?? 22, minute: settings?.cycleEndMinute ?? 0)
    }

    private var cyclesByDay: [Date: TradingCycle] {
        var map: [Date: TradingCycle] = [:]
        for cycle in cycles {
            let key = calendar.startOfDay(for: cycle.day)
            if map[key] == nil {
                map[key] = cycle
            }
        }
        return map
    }

    private var monthCycles: [TradingCycle] {
        cycles.filter { calendar.isDate($0.day, equalTo: monthAnchor, toGranularity: .month) }
    }

    private var monthR: Double {
        monthCycles.reduce(0) { $0 + r(of: $1) }
    }

    private var monthTint: Color {
        if monthR > 0.05 { return Theme.green }
        if monthR < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private var monthDays: [CalendarDay] {
        let start = startOfMonth(monthAnchor)
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let total = max(42, ((leading + daysInMonth + 6) / 7) * 7)

        return (0..<total).map { index in
            let date = calendar.date(byAdding: .day, value: index - leading, to: start) ?? start
            let key = calendar.startOfDay(for: date)
            return CalendarDay(
                id: key,
                date: date,
                inMonth: calendar.isDate(date, equalTo: start, toGranularity: .month),
                cycle: cyclesByDay[key]
            )
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .reveal(.drop)
                    monthHeader
                        .reveal(.zoom, 1)
                    gridCard
                        .reveal(.unfurl, 2)
                    Text("Выбранный день")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .reveal(.blur, 3)
                    selectedCard
                        .reveal(.rise, 4)
                    newsCard
                        .reveal(.rise, 5)
                    footer
                        .reveal(.rise, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable { await refreshNews() }
        }
        .fullScreenCover(item: $reviewTarget) { target in
            DayReviewView(day: target.day)
        }
        .task { await loadNews() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "История")
            ScreenTitle(text: "Календарь")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthHeader: some View {
        HStack(spacing: 10) {
            monthArrow("chevron.left") { shift(-1) }
            Spacer(minLength: 4)
            monthSummary
            Spacer(minLength: 4)
            monthArrow("chevron.right") { shift(1) }
        }
    }

    private var monthSummary: some View {
        (
            Text("\(Fmt.month(monthAnchor)) · ")
            + Text(Fmt.r(monthR)).foregroundColor(monthTint)
            + Text(" · \(Fmt.tradingDays(monthCycles.count))")
        )
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func monthArrow(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .glassCircle()
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    private var gridCard: some View {
        let newsMap = newsByDay

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                legendItem("TP", tint: Theme.green)
                legendItem("SL", tint: Theme.red)
                legendItem("BE", tint: Theme.orange)
                legendItem("Новости", tint: Theme.red)
            }

            HStack(spacing: 0) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7),
                spacing: 5
            ) {
                ForEach(monthDays) { day in
                    dayCell(day, newsMap: newsMap)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 26)
        .gesture(monthSwipe)
    }

    private func legendItem(_ text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func dayCell(_ day: CalendarDay, newsMap: [Date: [EconomicEvent]]) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let statusText = status(of: day.cycle)
        let tint = tint(of: day.cycle)
        let hasResult = statusText != nil && day.inMonth
        let dayValue = r(of: day.cycle)
        let isToday = calendar.isDateInToday(day.date)
        let dayNews = newsMap[calendar.startOfDay(for: day.date)] ?? []
        let hasHighNews = dayNews.contains { $0.impactKind == .high }

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedDate = day.date
            }
            openReview(for: day.date)
            Haptics.select()
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(numberColor(day, isSelected: isSelected))
                if hasResult, let statusText {
                    Text(statusText)
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(tint.opacity(0.22)))
                    Text(Fmt.r(dayValue))
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cellFill(day, hasResult: hasResult, tint: tint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Theme.blue
                            : (hasResult ? tint.opacity(0.35) : Color.white.opacity(0.04)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isToday && !isSelected {
                    Circle()
                        .fill(Theme.blue)
                        .frame(width: 4, height: 4)
                        .padding(5)
                }
            }
            .overlay(alignment: .bottom) {
                if day.inMonth, !dayNews.isEmpty {
                    Circle()
                        .fill(hasHighNews ? Theme.red : Theme.textSecondary)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 3)
                }
            }
            .shadow(color: isSelected ? Theme.blue.opacity(0.45) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(!day.inMonth)
    }

    private func cellFill(_ day: CalendarDay, hasResult: Bool, tint: Color) -> Color {
        guard day.inMonth else { return Color.white.opacity(0.02) }
        return hasResult ? tint.opacity(0.14) : Color.white.opacity(0.05)
    }

    private func numberColor(_ day: CalendarDay, isSelected: Bool) -> Color {
        guard day.inMonth else { return Theme.textTertiary.opacity(0.7) }
        if isSelected { return .white }
        return status(of: day.cycle) != nil ? .white : Theme.textPrimary.opacity(0.85)
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let width = value.translation.width
                if abs(width) > 55 {
                    shift(width < 0 ? 1 : -1)
                }
            }
    }

    // MARK: - Selected day

    private var selectedCard: some View {
        let cycle = cyclesByDay[calendar.startOfDay(for: selectedDate)]
        let trade = cycle?.trade
        let isClosed = trade.map { $0.result != .open } ?? false
        let tint = tint(of: cycle)

        return Button {
            openReview(for: selectedDate)
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("\(Fmt.shortDay(selectedDate)) · \(Fmt.weekday(selectedDate))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    if cycle != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                dayValueView(cycle: cycle, trade: trade, isClosed: isClosed, tint: tint)

                if let cycle {
                    HStack(spacing: 8) {
                        if let trade {
                            Text(trade.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            chip(trade.direction.rawValue, tint: trade.direction == .long ? Theme.green : Theme.red)
                            if isClosed {
                                chip(trade.result.rawValue, tint: tint)
                            }
                        } else {
                            Text("Сделки не было")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Text(cardFootnote(cycle))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(scenarioLine(cycle))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("В этот день цикла не было")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(cornerRadius: 26)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayValueView(
        cycle: TradingCycle?,
        trade: Trade?,
        isClosed: Bool,
        tint: Color
    ) -> some View {
        if let trade, isClosed {
            Text(Fmt.r(trade.actualR))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        } else if trade != nil {
            Text("позиция открыта")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.blue)
        } else {
            Text("—")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    private func cardFootnote(_ cycle: TradingCycle) -> String {
        if cycle.result == .draft {
            return "Цикл в работе · шаг \(cycle.step.number) из \(CycleStep.total)"
        }
        return "Цикл пройден · \(cycleStartText) → \(cycleEndText)"
    }

    private func scenarioLine(_ cycle: TradingCycle) -> String {
        let a = cycle.pointAPrice.map { Fmt.price($0) }
        let b = cycle.pointBPrice.map { Fmt.price($0) }
        switch (a, b) {
        case let (a?, b?):
            return "Сценарий: A \(a) → B \(b)"
        case let (a?, nil):
            return "Сценарий: A \(a), B не зафиксирован"
        default:
            return "Сценарий не зафиксирован"
        }
    }

    // MARK: - News

    private var newsByDay: [Date: [EconomicEvent]] {
        var map: [Date: [EconomicEvent]] = [:]
        for event in news {
            let key = calendar.startOfDay(for: event.date)
            map[key, default: []].append(event)
        }
        return map
    }

    private var selectedDayNews: [EconomicEvent] {
        let list = newsByDay[calendar.startOfDay(for: selectedDate)] ?? []
        return onlyHighImpact ? list.filter { $0.impactKind == .high } : list
    }

    private var newsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Новости Forex Factory")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Fmt.shortDay(selectedDate)) · \(Fmt.weekday(selectedDate))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 6)
                Button {
                    Task { await refreshNews() }
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(newsLoading)
            }

            HStack(spacing: 8) {
                Chip(title: "Все новости", isSelected: !onlyHighImpact) {
                    onlyHighImpact = false
                    Haptics.select()
                }
                Chip(title: "Только важные", isSelected: onlyHighImpact, tint: Theme.accent) {
                    onlyHighImpact = true
                    Haptics.select()
                }
                Spacer(minLength: 0)
            }

            if newsLoading && news.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.textSecondary)
                    Text("Загружаю календарь…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 8)
            } else if let newsError, selectedDayNews.isEmpty {
                InfoHint(text: newsError, tint: Theme.textTertiary, icon: "wifi.exclamationmark")
            } else if selectedDayNews.isEmpty {
                Text("На этот день новостей нет")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(selectedDayNews) { event in
                        newsRow(event)
                    }
                }
            }

            Text(newsFooterText)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var newsFooterText: String {
        var text = "Forex Factory · текущая неделя, время местное"
        if let newsUpdatedAt {
            text += " · обновлено \(Fmt.time(newsUpdatedAt))"
        }
        return text
    }

    private func newsRow(_ event: EconomicEvent) -> some View {
        let impact = event.impactKind
        let tint = newsTint(impact)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.country)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.time(event.date))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 6)
                Text(impact.title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.16)))
            }

            Text(event.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if event.forecastText != nil || event.previousText != nil || event.actualText != nil {
                HStack(spacing: 10) {
                    if let actual = event.actualText {
                        newsValue("Факт", actual)
                    }
                    if let forecast = event.forecastText {
                        newsValue("Прогноз", forecast)
                    }
                    if let previous = event.previousText {
                        newsValue("Пред.", previous)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(impact == .high ? Theme.red.opacity(0.07) : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    impact == .high ? Theme.red.opacity(0.25) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        )
    }

    private func newsTint(_ impact: NewsImpact) -> Color {
        switch impact {
        case .high: return Theme.red
        case .medium: return Theme.textPrimary
        case .low: return Theme.textSecondary
        case .holiday: return Theme.lavender
        }
    }

    private func newsValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func loadNews() async {
        news = EconomicCalendarService.loadCache()
        await refreshNews()
    }

    private func refreshNews() async {
        guard !newsLoading else { return }
        newsLoading = true
        defer { newsLoading = false }

        do {
            let list = try await EconomicCalendarService.fetchEvents()
            news = list
            newsError = nil
            newsUpdatedAt = .now
            EconomicCalendarService.saveCache(list)
        } catch {
            if news.isEmpty {
                news = EconomicCalendarService.loadCache()
            }
            newsError = news.isEmpty
                ? "Не удалось загрузить новости Forex Factory. Проверьте интернет."
                : "Не удалось обновить — показаны сохранённые данные."
        }
    }

    private var footer: some View {
        Text("Данные синхронизируются через iCloud")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    // MARK: - Helpers

    private func openReview(for date: Date) {
        reviewTarget = DayTarget(day: calendar.startOfDay(for: date))
    }

    private static func monthStart(_ date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func shift(_ delta: Int) {
        guard let newAnchor = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            monthAnchor = startOfMonth(newAnchor)
            if !calendar.isDate(selectedDate, equalTo: monthAnchor, toGranularity: .month) {
                selectedDate = monthAnchor
            }
        }
        Haptics.tap()
    }

    private func status(of cycle: TradingCycle?) -> String? {
        guard let cycle else { return nil }
        if cycle.stopDay { return "STOP DAY" }
        if let trade = cycle.trade, trade.result != .open {
            return trade.result.rawValue
        }
        return nil
    }

    private func tint(of cycle: TradingCycle?) -> Color {
        guard let cycle else { return .clear }
        if cycle.stopDay { return Theme.red }
        guard let trade = cycle.trade else { return .clear }
        switch trade.result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return .clear
        }
    }

    private func r(of cycle: TradingCycle?) -> Double {
        guard let trade = cycle?.trade, trade.result != .open else { return 0 }
        return trade.actualR
    }
}

// MARK: - Day details

private struct DayDetailSheet: View {
    let cycle: TradingCycle
    let cycleStartText: String
    let cycleEndText: String

    private var trade: Trade? { cycle.trade }

    private var accent: Color {
        if cycle.stopDay { return Theme.red }
        switch trade?.result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        default: return Theme.blue
        }
    }

    private var tradeItems: [SummaryItem] {
        guard let trade else { return [] }
        return [
            SummaryItem(title: "Символ", value: trade.symbol),
            SummaryItem(
                title: "Направление",
                value: trade.direction.rawValue,
                tint: trade.direction == .long ? Theme.green : Theme.red
            ),
            SummaryItem(title: "Entry", value: Fmt.price(trade.entry)),
            SummaryItem(title: "SL", value: Fmt.price(trade.currentStop), tint: Theme.red),
            SummaryItem(title: "TP", value: Fmt.price(trade.takeProfit), tint: Theme.green),
            SummaryItem(title: "RR", value: Fmt.rr(trade.plannedRR), tint: Theme.blue),
            SummaryItem(title: "Риск", value: Fmt.money(trade.riskUSD), tint: Theme.orange),
            SummaryItem(title: "Результат", value: trade.result.rawValue, tint: accent),
            SummaryItem(title: "Факт R", value: Fmt.r(trade.actualR), tint: accent)
        ]
    }

    private var cycleItems: [SummaryItem] {
        [
            SummaryItem(
                title: "Направление",
                value: cycle.direction.rawValue,
                tint: cycle.direction == .long ? Theme.green : Theme.red
            ),
            SummaryItem(title: "Последний DR", value: drText),
            SummaryItem(title: "Зона", value: cycle.zone?.rawValue ?? "—"),
            SummaryItem(title: "Point A", value: Fmt.price(cycle.pointAPrice)),
            SummaryItem(title: "Point B", value: Fmt.price(cycle.pointBPrice)),
            SummaryItem(title: "Подтверждения", value: "\(cycle.confirmations.count) из 6"),
            SummaryItem(title: "Key Levels", value: "\(cycle.activeKeyLevels.count) активных")
        ]
    }

    private var drText: String {
        guard let high = cycle.drHigh, let low = cycle.drLow else { return "—" }
        return "\(Fmt.price(low)) – \(Fmt.price(high))"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Fmt.shortDay(cycle.day)) · \(Fmt.weekday(cycle.day))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text(trade.map { Fmt.r($0.actualR) } ?? "—")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        Text(cycle.stopDay ? "STOP DAY" : (trade?.result.rawValue ?? "нет сделки"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(accent.opacity(0.16)))
                        Spacer(minLength: 0)
                    }
                    Text("Цикл \(cycleStartText) → \(cycleEndText)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                }

                if !tradeItems.isEmpty {
                    SummaryTable(items: tradeItems)
                }

                SummaryTable(items: cycleItems)

                if cycle.stopDay {
                    InfoHint(
                        text: "SL в этот день: новых входов не было до следующего цикла.",
                        tint: Theme.red,
                        icon: "exclamationmark.octagon"
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }
}

//
//  TradesView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

enum TradeFilter: String, CaseIterable, Identifiable {
    case open = "Открытые"
    case closed = "Закрытые"
    case all = "Все"

    var id: String { rawValue }
}

enum TradesMode: String, CaseIterable, Identifiable {
    case trades = "Сделки"
    case plans = "Планы"

    var id: String { rawValue }
}

struct TradesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate, order: .reverse)
    private var trades: [Trade]

    @Query(sort: \TradePlan.day, order: .reverse)
    private var plans: [TradePlan]

    @Query private var settingsList: [AppSettings]

    @State private var mode: TradesMode = .trades
    @State private var planFilter: PlanResult? = nil
    @State private var filter: TradeFilter = .all
    @State private var activeSheet: TradesSheet?
    @State private var activeCover: TradesCover?

    private enum TradesCover: Identifiable {
        case gallery(Trade)
        case trade(Trade)
        case plan(TradePlan)
        case newTrade

        var id: String {
            switch self {
            case .gallery(let trade):
                return "gallery-\(trade.persistentModelID.hashValue)"
            case .trade(let trade):
                return "trade-\(trade.persistentModelID.hashValue)"
            case .plan(let plan):
                return "plan-\(plan.persistentModelID.hashValue)"
            case .newTrade:
                return "new-trade"
            }
        }
    }

    @State private var searchText = ""
    @State private var selectedSymbols: Set<String> = []
    @State private var selectedDirection: Direction?
    @State private var selectedResult: TradeResult?
    @State private var selectedTags: Set<String> = []

    private enum TradesSheet: Identifiable {
        case filters

        var id: String {
            switch self {
            case .filters:
                return "filters"
            }
        }
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    @State private var useDateRange = false
    @State private var rangeStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var rangeEnd: Date = .now

    private var symbols: [String] {
        Array(Set(trades.map(\.symbol))).sorted()
    }

    private var segmentTrades: [Trade] {
        switch filter {
        case .open:
            return trades.filter { $0.result == .open }
        case .closed:
            return trades.filter { $0.result != .open }
        case .all:
            return trades
        }
    }

    private var filteredTrades: [Trade] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = Calendar.current.startOfDay(for: min(rangeStart, rangeEnd))
        let upper = Calendar.current.startOfDay(for: max(rangeStart, rangeEnd))
        let upperEnd = Calendar.current.date(byAdding: .day, value: 1, to: upper) ?? upper

        return segmentTrades.filter { trade in
            if !selectedSymbols.isEmpty && !selectedSymbols.contains(trade.symbol) {
                return false
            }
            if let selectedDirection, trade.direction != selectedDirection {
                return false
            }
            if let selectedResult, trade.result != selectedResult {
                return false
            }
            if !selectedTags.isEmpty && Set(trade.tags).isDisjoint(with: selectedTags) {
                return false
            }
            if useDateRange {
                let day = Calendar.current.startOfDay(for: trade.tradingDay)
                if day < lower || day >= upperEnd {
                    return false
                }
            }
            if !query.isEmpty {
                let matchesSymbol = trade.symbol.localizedCaseInsensitiveContains(query)
                let matchesNote = trade.note.localizedCaseInsensitiveContains(query)
                if !matchesSymbol && !matchesNote {
                    return false
                }
            }
            return true
        }
    }

    private var openCount: Int {
        filteredTrades.filter { $0.result == .open }.count
    }

    private var todayR: Double {
        filteredTrades
            .filter { trade in
                guard let closedAt = trade.closedAt else { return false }
                return Calendar.current.isDateInToday(closedAt)
            }
            .reduce(0) { $0 + $1.actualR }
    }

    private var hasActiveFilters: Bool {
        !selectedSymbols.isEmpty
            || selectedDirection != nil
            || selectedResult != nil
            || !selectedTags.isEmpty
            || useDateRange
    }

    private var activeFilterCount: Int {
        selectedSymbols.count
            + (selectedDirection != nil ? 1 : 0)
            + (selectedResult != nil ? 1 : 0)
            + selectedTags.count
            + (useDateRange ? 1 : 0)
    }

    private var hasAnyQuery: Bool {
        hasActiveFilters || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var todayRColor: Color {
        if todayR > 0.05 { return Theme.green }
        if todayR < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    GlassSegmented(
                        options: TradesMode.allCases,
                        selection: $mode,
                        label: { $0.rawValue },
                        tint: { _ in Theme.accent }
                    )

                    if mode == .trades {
                        GlassSegmented(
                            options: TradeFilter.allCases,
                            selection: $filter,
                            label: { $0.rawValue },
                            tint: { _ in Color.white.opacity(0.16) }
                        )

                        if hasActiveFilters {
                            activeChipsRow
                        }

                        searchRow

                        if filteredTrades.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredTrades) { trade in
                                    card(for: trade)
                                }
                            }
                        }
                    } else {
                        planFiltersRow

                        if filteredPlans.isEmpty {
                            plansEmptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredPlans) { plan in
                                    planCard(plan)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .filters:
                TradeFiltersSheet(
                    symbols: symbols,
                    usedTags: usedTags,
                    selectedSymbols: $selectedSymbols,
                    selectedDirection: $selectedDirection,
                    selectedResult: $selectedResult,
                    selectedTags: $selectedTags,
                    useDateRange: $useDateRange,
                    rangeStart: $rangeStart,
                    rangeEnd: $rangeEnd,
                    onReset: { resetFilters() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
            }
        }
        .fullScreenCover(item: $activeCover) { cover in
            switch cover {
            case .gallery(let trade):
                ScreenshotsGallery(trade: trade)
            case .trade(let trade):
                TradeDetailView(trade: trade, usedTags: usedTags)
            case .plan(let plan):
                PlanView(plan: plan)
            case .newTrade:
                NewTradeView()
            }
        }
    }

    // MARK: - Plans

    private var filteredPlans: [TradePlan] {
        guard let planFilter else { return plans }
        return plans.filter { $0.result == planFilter }
    }

    private var planFiltersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Все", isSelected: planFilter == nil) {
                    planFilter = nil
                    Haptics.select()
                }
                ForEach(PlanResult.allCases) { result in
                    Chip(
                        title: result.rawValue,
                        isSelected: planFilter == result,
                        tint: planTint(result)
                    ) {
                        planFilter = planFilter == result ? nil : result
                        Haptics.select()
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func planTint(_ result: PlanResult) -> Color {
        switch result {
        case .win: return Theme.green
        case .loss: return Theme.red
        case .be: return Theme.orange
        case .skip: return Theme.textSecondary
        case .noTrade: return Theme.accent
        case .pending: return Theme.textSecondary
        }
    }

    private func planCard(_ plan: TradePlan) -> some View {
        Button {
            activeCover = .plan(plan)
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(plan.symbol)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(plan.direction.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill((plan.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                        )
                    Spacer(minLength: 6)
                    Text(plan.result.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(planTint(plan.result))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(planTint(plan.result).opacity(0.14)))
                        .overlay(Capsule().strokeBorder(planTint(plan.result).opacity(0.35), lineWidth: 1))
                }

                Text(Fmt.shortDay(plan.day))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                if !plan.title.isEmpty {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if !plan.thesis.isEmpty {
                    Text(plan.thesis)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 6) {
                    miniPill(
                        "Чек-лист \(plan.checkedCount)/\(PlanCheck.allCases.count)",
                        tint: plan.isChecklistComplete ? Theme.green : Theme.orange
                    )
                    if plan.hasPlanA { miniPill("A", tint: Theme.accent) }
                    if plan.hasPlanB { miniPill("B", tint: Theme.accent) }
                    if plan.hasAdaptation { miniPill("Адаптация", tint: Theme.lavender) }
                    if !plan.photos.isEmpty { miniPill("Фото \(plan.photos.count)", tint: Theme.textSecondary) }
                    if !plan.trades.isEmpty { miniPill("Сделок \(plan.trades.count)", tint: Theme.blue) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(cornerRadius: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func miniPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private var plansEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plans.isEmpty ? "Планов пока нет" : "Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                plans.isEmpty
                    ? "План дня: идея, сценарии A и B, адаптация, чек-лист системы, скриншоты и прикреплённые сделки."
                    : "Смените фильтр по итогу плана — сами планы не менялись."
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            if plans.isEmpty {
                Button {
                    createPlan()
                } label: {
                    Text("Создать план")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func createPlan() {
        let symbol = settingsList.first?.symbols.first ?? "EURUSD"
        let plan = TradePlan(
            day: Calendar.current.startOfDay(for: .now),
            symbol: symbol,
            direction: .long
        )
        context.insert(plan)
        try? context.save()
        activeCover = .plan(plan)
        Haptics.success()
    }

    // MARK: - Search and filters

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Поиск по символу или заметке", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(Theme.blue)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )

            Button {
                activeSheet = .filters
                Haptics.tap()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasActiveFilters ? .white : Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveFilters ? Theme.blue.opacity(0.30) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    hasActiveFilters ? Theme.blue.opacity(0.5) : Color.white.opacity(0.07),
                                    lineWidth: 1
                                )
                        )
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Theme.blue))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var activeChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeChips) { chip in
                    activeChipView(chip)
                }
                Button {
                    resetFilters()
                    Haptics.tap()
                } label: {
                    Text("Сбросить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 1)
        }
    }

    private struct ActiveChip: Identifiable {
        let id: String
        let title: String
        let tint: Color?
        let remove: () -> Void
    }

    private var activeChips: [ActiveChip] {
        var chips: [ActiveChip] = []
        for symbol in selectedSymbols.sorted() {
            chips.append(ActiveChip(id: "symbol-\(symbol)", title: symbol, tint: nil) {
                selectedSymbols.remove(symbol)
            })
        }
        if let direction = selectedDirection {
            chips.append(
                ActiveChip(
                    id: "direction",
                    title: direction.rawValue,
                    tint: direction == .long ? Theme.green : Theme.red
                ) {
                    selectedDirection = nil
                }
            )
        }
        if let result = selectedResult {
            chips.append(
                ActiveChip(id: "result", title: tradeResultTitle(result), tint: tradeResultTint(result)) {
                    selectedResult = nil
                }
            )
        }
        if useDateRange {
            chips.append(ActiveChip(id: "dates", title: dateChipTitle, tint: Theme.blue) {
                useDateRange = false
            })
        }
        for tag in selectedTags.sorted() {
            chips.append(ActiveChip(id: "tag-\(tag)", title: tag, tint: Theme.blue) {
                selectedTags.remove(tag)
            })
        }
        return chips
    }

    private func activeChipView(_ chip: ActiveChip) -> some View {
        let tint = chip.tint ?? Color.white.opacity(0.5)
        return HStack(spacing: 6) {
            Text(chip.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(chip.tint == nil ? Theme.textPrimary : tint)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    chip.remove()
                }
                Haptics.tap()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.16)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }

    private var dateChipTitle: String {
        let cal = Calendar.current
        let start = min(rangeStart, rangeEnd)
        let end = max(rangeStart, rangeEnd)
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(cal.component(.day, from: start))–\(Fmt.shortDay(end))"
        }
        return "\(Fmt.shortDay(start)) – \(Fmt.shortDay(end))"
    }

    private func resetFilters() {
        selectedSymbols = []
        selectedDirection = nil
        selectedResult = nil
        selectedTags = []
        useDateRange = false
        searchText = ""
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Журнал")
                ScreenTitle(text: "Сделки")
            }
            Spacer(minLength: 8)
            if mode == .trades {
                summaryCapsule
                    .padding(.bottom, 4)
            } else {
                planSummaryCapsule
                    .padding(.bottom, 4)
            }
            Button {
                if mode == .plans {
                    createPlan()
                } else {
                    activeCover = .newTrade
                }
                Haptics.tap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.4), radius: 10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
    }

    private var planSummaryCapsule: some View {
        let compliant = plans.filter { $0.isChecklistComplete }.count
        return (
            Text("Планов \(plans.count) · ")
            + Text("по системе \(compliant)").foregroundColor(Theme.green)
        )
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var summaryCapsule: some View {
        (
            Text("Открыто \(openCount) · сегодня ")
            + Text(Fmt.r(todayR)).foregroundColor(todayRColor)
        )
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Cards

    private func card(for trade: Trade) -> some View {
        Button {
            activeCover = .trade(trade)
            Haptics.tap()
        } label: {
            Group {
                if trade.result == .open {
                    openCard(trade)
                } else {
                    closedCard(trade)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openCard(_ trade: Trade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(trade.symbol)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                directionBadge(trade)
                Spacer(minLength: 4)
                if let badge = carryBadge(trade) {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.orange.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.45), lineWidth: 1))
                }
            }

            Text(openDetail(trade))
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 8) {
                TradePill(text: "RR \(String(format: "%.1f", trade.plannedRR))")
                TradePill(
                    text: "\(Fmt.money(trade.riskUSD)) · ступень \(trade.ladderStepIndex + 1)",
                    tint: Theme.blue,
                    emphasized: true
                )
                Spacer(minLength: 0)
            }

            if !trade.tags.isEmpty {
                tagsRow(trade.tags)
            }

            if !trade.shots.isEmpty {
                shotsPreview(trade.sortedShots)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func closedCard(_ trade: Trade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(trade.symbol)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                directionBadge(trade)
                Spacer(minLength: 4)
                Text(Fmt.r(trade.actualR))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(rColor(trade.actualR))
            }

            Text("Entry \(Fmt.price(trade.entry)) · TP \(Fmt.price(trade.takeProfit))")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 8) {
                resultPill(trade)
                TradePill(text: Fmt.money(trade.riskUSD), tint: Theme.blue, emphasized: true)
                Spacer(minLength: 0)
                Text(Fmt.shortDay(trade.tradingDay))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            if !trade.tags.isEmpty {
                tagsRow(trade.tags)
            }

            if !trade.shots.isEmpty {
                shotsPreview(trade.sortedShots)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func tagsRow(_ tags: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(tags.prefix(3)), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
            }
            if tags.count > 3 {
                Text("+\(tags.count - 3)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func shotsPreview(_ shots: [TradeShot]) -> some View {
        HStack(spacing: 6) {
            ForEach(shots.prefix(3)) { shot in
                ShotThumbnail(shot: shot, size: 44)
            }
            if shots.count > 3 {
                Text("+\(shots.count - 3)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func directionBadge(_ trade: Trade) -> some View {
        Text(trade.direction.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
            )
    }

    private func resultPill(_ trade: Trade) -> some View {
        let tint: Color
        switch trade.result {
        case .tp: tint = Theme.green
        case .sl: tint = Theme.red
        case .be: tint = Theme.orange
        case .open: tint = Theme.textSecondary
        }
        return TradePill(text: trade.result.rawValue, tint: tint)
    }

    private func carryBadge(_ trade: Trade) -> String? {
        guard trade.result == .open else { return nil }
        if !Calendar.current.isDateInToday(trade.tradingDay) {
            return trade.isBE ? "BE · с \(Fmt.shortDay(trade.tradingDay))" : "с \(Fmt.shortDay(trade.tradingDay))"
        }
        return trade.isBE ? "BE" : nil
    }

    private func openDetail(_ trade: Trade) -> String {
        "Entry \(Fmt.price(trade.entry)) · SL \(Fmt.price(trade.currentStop)) · TP \(Fmt.price(trade.takeProfit))"
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if hasAnyQuery {
                Button {
                    resetFilters()
                    Haptics.tap()
                } label: {
                    Text("Сбросить поиск и фильтры")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var emptyTitle: String {
        if hasAnyQuery { return "Ничего не найдено" }
        switch filter {
        case .open: return "Открытых сделок нет"
        case .closed: return "Закрытых сделок нет"
        case .all: return "Сделок пока нет"
        }
    }

    private var emptyMessage: String {
        if hasAnyQuery {
            return "Измените запрос или сбросьте фильтры — сами сделки не менялись."
        }
        switch filter {
        case .open: return "Позиция появится здесь сразу после ENTRY в цикле."
        case .closed: return "Закрой позицию по TP, SL или BE — она останется в журнале."
        case .all: return "Пройдите цикл и откройте сделку — она появится здесь."
        }
    }
}

// MARK: - Pill

private struct TradePill: View {
    let text: String
    var tint: Color? = nil
    var emphasized: Bool = false

    private var base: Color { tint ?? Color.white }
    private var isTinted: Bool { tint != nil }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(emphasized ? Color.white : (isTinted ? base : Theme.textSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(base.opacity(emphasized ? 0.26 : (isTinted ? 0.16 : 0.06)))
            )
            .overlay(
                Capsule().strokeBorder(base.opacity(emphasized ? 0.4 : (isTinted ? 0.4 : 0.1)), lineWidth: 1)
            )
    }
}

// MARK: - Close sheet

struct TradeCloseSheet: View {
    let trade: Trade
    let usedTags: [String]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Закрыть сделку")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(trade.symbol)
                            .fontWeight(.semibold)
                        Text("·")
                        Text(trade.direction.rawValue)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 10) {
                    resultButton("TP", tint: Theme.green, result: .tp)
                    resultButton("BE", tint: Theme.orange, result: .be)
                    resultButton("SL", tint: Theme.red, result: .sl)
                }

                Button {
                    moveToBE()
                } label: {
                    Text(trade.isBE ? "SL уже в BE" : "Перевести в BE")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(trade.isBE ? Theme.textTertiary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(trade.isBE)
                .opacity(trade.isBE ? 0.6 : 1)

                TradeTagEditor(trade: trade, usedTags: usedTags)

                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var caption: String {
        if trade.isBE {
            return "SL уже в BE: закрытие по SL даст 0R."
        }
        return "SL — минус 1R и STOP DAY до завтрашних 19:00. BE — 0R. 22:00: перевести SL в BE и закрыть терминал."
    }

    private func resultButton(_ title: String, tint: Color, result: TradeResult) -> some View {
        Button {
            close(result)
        } label: {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.72))
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func close(_ result: TradeResult) {
        switch result {
        case .tp:
            trade.actualR = trade.plannedRR
        case .sl:
            trade.actualR = trade.isBE ? 0 : -1
        case .be:
            trade.actualR = 0
        case .open:
            return
        }

        trade.result = result
        trade.closedAt = .now

        if result == .sl,
           let cycle = trade.cycle,
           Calendar.current.isDateInToday(trade.tradingDay) {
            cycle.stopDay = true
            cycle.updatedAt = .now
        }

        try? context.save()
        LadderEngine.sync(context: context)

        if result == .sl {
            Haptics.warning()
        } else {
            Haptics.success()
        }
        dismiss()
    }

    private func moveToBE() {
        guard !trade.isBE else { return }
        trade.currentStop = trade.entry
        trade.isBE = true
        try? context.save()
        Haptics.success()
        dismiss()
    }
}


// MARK: - Result labels

private func tradeResultTitle(_ result: TradeResult) -> String {
    switch result {
    case .tp: return "TP"
    case .sl: return "SL"
    case .be: return "BE"
    case .open: return "Открыта"
    }
}

private func tradeResultTint(_ result: TradeResult) -> Color {
    switch result {
    case .tp: return Theme.green
    case .sl: return Theme.red
    case .be: return Theme.orange
    case .open: return Theme.blue
    }
}

// MARK: - Filters sheet

private struct TradeFiltersSheet: View {
    let symbols: [String]
    let usedTags: [String]

    @Binding var selectedSymbols: Set<String>
    @Binding var selectedDirection: Direction?
    @Binding var selectedResult: TradeResult?
    @Binding var selectedTags: Set<String>

    @Binding var useDateRange: Bool
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date

    var onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Фильтры")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                }

                section("СИМВОЛ") {
                    if symbols.isEmpty {
                        Text("В журнале пока нет символов")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Chip(
                                        title: symbol,
                                        isSelected: selectedSymbols.contains(symbol)
                                    ) {
                                        toggleSymbol(symbol)
                                    }
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

                section("НАПРАВЛЕНИЕ") {
                    HStack(spacing: 8) {
                        Chip(
                            title: "LONG",
                            isSelected: selectedDirection == .long,
                            tint: Theme.green
                        ) {
                            toggleDirection(.long)
                        }
                        Chip(
                            title: "SHORT",
                            isSelected: selectedDirection == .short,
                            tint: Theme.red
                        ) {
                            toggleDirection(.short)
                        }
                    }
                }

                section("РЕЗУЛЬТАТ") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([TradeResult.tp, .sl, .be, .open], id: \.self) { result in
                                Chip(
                                    title: tradeResultTitle(result),
                                    isSelected: selectedResult == result,
                                    tint: tradeResultTint(result)
                                ) {
                                    toggleResult(result)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                if !usedTags.isEmpty {
                    section("МЕТКИ") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(usedTags, id: \.self) { tag in
                                    Chip(
                                        title: tag,
                                        isSelected: selectedTags.contains(tag),
                                        tint: Theme.blue
                                    ) {
                                        toggleTag(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

                section("ПЕРИОД") {
                    Toggle("Ограничить даты", isOn: $useDateRange)
                        .tint(Theme.blue)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)

                    if useDateRange {
                        HStack(spacing: 12) {
                            dateField("С", date: $rangeStart)
                            dateField("По", date: $rangeEnd)
                        }
                    }
                }

                Button {
                    onReset()
                    Haptics.tap()
                } label: {
                    Text("Сбросить всё")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.red.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateField(_ label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func toggleSymbol(_ symbol: String) {
        if selectedSymbols.contains(symbol) {
            selectedSymbols.remove(symbol)
        } else {
            selectedSymbols.insert(symbol)
        }
        Haptics.select()
    }

    private func toggleDirection(_ direction: Direction) {
        selectedDirection = selectedDirection == direction ? nil : direction
        Haptics.select()
    }

    private func toggleResult(_ result: TradeResult) {
        selectedResult = selectedResult == result ? nil : result
        Haptics.select()
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        Haptics.select()
    }
}

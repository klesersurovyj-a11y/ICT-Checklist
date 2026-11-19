//
//  TerminalView.swift
//  ICT Checklist
//
//  Рыночный терминал: тикерная лента, вотчлист, лента событий и макро.
//

import SwiftUI
import SwiftData

struct TerminalView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]

    @AppStorage("terminal.watchlist") private var watchlistRaw = "EURUSD,GBPUSD,XAUUSD,US500"

    @State private var quotes: [String: TerminalQuote] = [:]
    @State private var events: [EconomicEvent] = []
    @State private var macro: [String: EconomySnapshot] = [:]
    @State private var isLoadingQuotes = false
    @State private var priceDeltas: [String: Double] = [:]
    @State private var errorText: String?

    @State private var showWatchlistEditor = false
    @State private var showCalendar = false
    @State private var showWorldMap = false

    private var watchlist: [String] {
        watchlistRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    tickerStrip
                        .reveal(.slideLeft, 1)

                    watchlistCard
                        .reveal(.zoom, 2)

                    eventsCard
                        .reveal(.rise, 3)

                    macroCard
                        .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await reloadQuotes(force: true)
                await loadEvents()
                await loadMacro()
            }
            .overlay(alignment: .top) {
                if isLoadingQuotes {
                    RefreshRing()
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
        }
        .task {
            quotes = MarketQuoteService.loadCache()
            macro = WorldEconomyService.loadCache()
            events = cachedTodayEvents()
            await reloadQuotes(force: false)
            await loadEvents()
            await loadMacro()
        }
        .onChange(of: watchlistRaw) { _, _ in
            Task { await reloadQuotes(force: true) }
        }
        .sheet(isPresented: $showWatchlistEditor) {
            TerminalWatchlistSheet(symbols: watchlist, suggestions: suggestedSymbols()) { updated in
                watchlistRaw = updated.joined(separator: ",")
            }
        }
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarView()
        }
        .fullScreenCover(isPresented: $showWorldMap) {
            WorldEconomyView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
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

                Spacer(minLength: 0)

                Button {
                    Task { await reloadQuotes(force: true) }
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(isLoadingQuotes)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .glassCircle()
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Терминал · Рынок")
                ScreenTitle(text: "Терминал")
                Text("Цены, события и макро в одном окне")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSecondary)
                    .windIn(delay: 0.8)
            }
        }
    }

    // MARK: - Ticker

    private var tickerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(watchlist, id: \.self) { symbol in
                    ticker(symbol)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func ticker(_ symbol: String) -> some View {
        let quote = quotes[symbol]
        return VStack(alignment: .leading, spacing: 4) {
            Text(symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 6) {
                Text(quote.map { MarketQuoteService.priceText($0.price) } ?? "—")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)

                if let quote {
                    Text(MarketQuoteService.changeText(quote))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint(quote.percentChange))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minWidth: 124, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Watchlist

    private var watchlistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Вотчлист") {
                showWatchlistEditor = true
            }

            if watchlist.isEmpty {
                Text("Вотчлист пуст. Добавьте инструменты, чтобы видеть цены.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(spacing: 0) {
                    Text("Инструмент")
                        .frame(width: 66, alignment: .leading)
                    Text("Цена")
                        .frame(width: 66, alignment: .trailing)
                    Text("День")
                        .frame(width: 46, alignment: .trailing)
                    Text("Диапазон")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 6)
                    Text("Позиция")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)

                if isLoadingQuotes && quotes.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        skeletonRow
                    }
                } else {
                    ForEach(watchlist, id: \.self) { symbol in
                        watchRow(symbol)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !quotes.isEmpty {
                    Text("Цены обновляются при открытии и по кнопке в шапке.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func watchRow(_ symbol: String) -> some View {
        let quote = quotes[symbol]
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 66, alignment: .leading)

                Text(quote.map { q in
                    let base = MarketQuoteService.priceText(q.price)
                    guard let delta = priceDeltas[symbol] else { return base }
                    return base + (delta > 0 ? " ▴" : " ▾")
                } ?? "—")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        priceDeltas[symbol].map { $0 > 0 ? Theme.green : Theme.red } ?? Theme.textPrimary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 66, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: quote?.price)

                Text(quote.map { MarketQuoteService.changeText($0) } ?? "—")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(quote.map { tint($0.percentChange) } ?? Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 46, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: quote?.percentChange)

                Text(quote.map { MarketQuoteService.rangeText($0) } ?? "—")
                    .font(.system(size: 9.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)

                positionBadge(symbol)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func positionBadge(_ symbol: String) -> some View {
        if let position = openPosition(symbol) {
            Text("\(position.direction.rawValue) \(String(format: "%.1f", position.riskR))R")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(position.direction == .long ? Theme.green : Theme.red)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        (position.direction == .long ? Theme.green : Theme.red).opacity(0.16)
                    )
                )
        } else {
            Text("нет")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        }
    }

    private struct OpenPosition {
        let direction: Direction
        let riskR: Double
    }

    private func openPosition(_ symbol: String) -> OpenPosition? {
        let matches = trades.filter {
            $0.result == .open && $0.symbol.localizedCaseInsensitiveContains(symbol)
        }
        guard let trade = matches.first else { return nil }
        let step = settingsList.first?.ladderAmount(at: trade.ladderStepIndex) ?? 0
        let riskR = step > 0.01 ? trade.riskUSD / step : trade.riskUSD
        return OpenPosition(direction: trade.direction, riskR: riskR)
    }

    private var skeletonRow: some View {
        HStack(spacing: 0) {
            SkeletonBar(width: 46, height: 10)
                .frame(width: 66, alignment: .leading)
            Spacer(minLength: 0)
            SkeletonBar(width: 46, height: 10)
                .frame(width: 66, alignment: .trailing)
            SkeletonBar(width: 30, height: 10)
                .frame(width: 46, alignment: .trailing)
            SkeletonBar(height: 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
            SkeletonBar(width: 50, height: 10)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Events

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Лента событий") {
                showCalendar = true
            }

            if events.isEmpty {
                Text("На сегодня событий нет или календарь ещё не загружен.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(Array(events.prefix(4))) { event in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(event.impactKind == .high ? Theme.orange : Theme.textTertiary)
                            .frame(width: 7, height: 7)

                        Text(Fmt.time(event.date))
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, alignment: .leading)

                        Text(event.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        Text(event.impactKind.title.lowercased())
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(event.impactKind == .high ? Theme.orange : Theme.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    (event.impactKind == .high ? Theme.orange : Theme.textSecondary)
                                        .opacity(0.14)
                                )
                            )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Macro

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Макро") {
                showWorldMap = true
            }

            ForEach(EconomyRegion.allCases) { region in
                let snapshot = macro[region.countryCode]
                Button {
                    showWorldMap = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 10) {
                        Text(region.currency)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 34, height: 22)
                            .background(Capsule().fill(Color.white.opacity(0.07)))

                        Text(region.rawValue)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 78, alignment: .leading)

                        Spacer(minLength: 0)

                        Text("ВВП \(WorldEconomyService.percentText(snapshot?.growth))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)

                        Text("Инфляция \(WorldEconomyService.percentText(snapshot?.inflation))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minWidth: 118, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Card header

    private func cardHeader(_ title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 0)

            Button {
                action()
                Haptics.tap()
            } label: {
                HStack(spacing: 3) {
                    Text("Все")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Load

    private func suggestedSymbols() -> [String] {
        var list = settingsList.first?.symbols ?? []
        list.append(contentsOf: ["EURUSD", "GBPUSD", "XAUUSD", "US500", "US30", "NAS100", "BTCUSD"])
        var seen = Set<String>()
        return list
            .map { $0.uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func cachedTodayEvents() -> [EconomicEvent] {
        let cached = EconomicCalendarService.loadCache()
        let calendar = Calendar.current
        let today = cached.filter { calendar.isDateInToday($0.date) }
        if !today.isEmpty {
            return today.sorted { $0.date < $1.date }
        }
        return cached.filter { $0.date > .now }.sorted { $0.date < $1.date }
    }

    @MainActor
    private func reloadQuotes(force: Bool) async {
        let symbols = watchlist
        guard !symbols.isEmpty else { return }

        isLoadingQuotes = true
        errorText = nil

        var updated = quotes
        var fetched = 0

        for symbol in symbols {
            if !force,
               let cached = updated[symbol],
               Date().timeIntervalSince(cached.updatedAt) < 60 {
                continue
            }
            // Бесплатный тариф Twelve Data: 8 запросов в минуту.
            if fetched >= 4 { break }

            do {
                let quote = try await MarketQuoteService.fetch(symbol: symbol)
                updated[symbol] = quote
            } catch {
                if errorText == nil {
                    errorText = "Не удалось обновить цены: проверьте ключ Twelve Data или попробуйте позже."
                }
            }
            fetched += 1
        }

        var deltas: [String: Double] = [:]
        for (symbol, quote) in updated {
            if let previous = quotes[symbol]?.price, abs(previous - quote.price) > 0.0000001 {
                deltas[symbol] = quote.price - previous
            }
        }

        quotes = updated
        MarketQuoteService.saveCache(updated)
        isLoadingQuotes = false

        if !deltas.isEmpty {
            priceDeltas = deltas
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeOut(duration: 0.6)) {
                    priceDeltas = [:]
                }
            }
        }
    }

    @MainActor
    private func loadEvents() async {
        if let fresh = try? await EconomicCalendarService.fetchEvents() {
            EconomicCalendarService.saveCache(fresh)
            let calendar = Calendar.current
            let today = fresh.filter { calendar.isDateInToday($0.date) }
            events = (today.isEmpty ? fresh.filter { $0.date > .now } : today)
                .sorted { $0.date < $1.date }
        }
    }

    @MainActor
    private func loadMacro() async {
        if let fresh = try? await WorldEconomyService.fetch() {
            macro = fresh
        } else if macro.isEmpty {
            macro = WorldEconomyService.loadCache()
        }
    }

    private func tint(_ value: Double) -> Color {
        if value > 0.005 { return Theme.green }
        if value < -0.005 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Watchlist editor

private struct TerminalWatchlistSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var symbols: [String]
    @State private var newSymbol = ""

    let suggestions: [String]
    let onSave: ([String]) -> Void

    init(symbols: [String], suggestions: [String], onSave: @escaping ([String]) -> Void) {
        _symbols = State(initialValue: symbols)
        self.suggestions = suggestions
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionLabel(text: "Терминал · Вотчлист")
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

                    ScreenTitle(text: "Инструменты")

                    HStack(spacing: 8) {
                        TextField("Символ, например EURUSD", text: $newSymbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .tint(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )

                        Button {
                            add(newSymbol)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.background)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Theme.accent))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(symbols.enumerated()), id: \.element) { index, symbol in
                            if index > 0 {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                            HStack {
                                Text(symbol)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer(minLength: 0)
                                Button {
                                    symbols.removeAll { $0 == symbol }
                                    Haptics.tap()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Theme.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                        }

                        if symbols.isEmpty {
                            Text("Пока пусто")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 14)
                    .glassCard(cornerRadius: 20)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Быстро добавить")
                        FlowChips(items: suggestions.filter { !symbols.contains($0) }) { symbol in
                            add(symbol)
                        }
                    }

                    PrimaryButton(title: "Готово") {
                        onSave(symbols)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
    }

    private func add(_ value: String) {
        let symbol = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty, !symbols.contains(symbol) else { return }
        symbols.append(symbol)
        newSymbol = ""
        Haptics.tap()
    }
}

private struct FlowChips: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        action(item)
                    } label: {
                        Text(item)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .glassCapsule()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

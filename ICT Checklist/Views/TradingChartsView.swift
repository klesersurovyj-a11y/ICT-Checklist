//
//  TradingChartsView.swift
//  ICT Checklist
//
//  Графики TradingView: инструменты и таймфреймы, а для сделки —
//  вход, стоп, тейк, уровни дня и текущая цена.
//

import SwiftUI
import SwiftData

struct TradingChartsView: View {
    var initialSymbol: String?
    var trade: Trade?

    init(initialSymbol: String? = nil, trade: Trade? = nil) {
        self.initialSymbol = initialSymbol
        self.trade = trade
    }

    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @ObservedObject private var prices = PriceBook.shared

    @State private var selectedSymbol = ""
    @State private var interval: TVInterval = .h1
    @State private var customSymbol = ""
    @State private var showCustomSymbol = false

    @State private var bars: [ChartBar] = []
    @State private var isLoadingBars = false
    @State private var barsError: String?

    private var isTradeMode: Bool { trade != nil }

    private var symbols: [String] {
        var list = settingsList.first?.symbols ?? []
        let preferred = trade?.symbol ?? initialSymbol
        if let preferred,
           !list.contains(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
            list.insert(preferred, at: 0)
        }
        if list.isEmpty {
            list = ["EURUSD", "GBPUSD", "XAUUSD"]
        }
        return list
    }

    private var symbol: String {
        trade?.symbol ?? (selectedSymbol.isEmpty ? symbols.first ?? "EURUSD" : selectedSymbol)
    }

    private var tvSymbol: String {
        TradingViewSymbol.map(symbol)
    }

    private var externalURL: URL {
        let encoded = tvSymbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tvSymbol
        return URL(string: "https://www.tradingview.com/chart/?symbol=\(encoded)")
            ?? URL(string: "https://www.tradingview.com/chart/")!
    }

    private var currentPrice: Double? {
        guard let trade, trade.result == .open else { return nil }
        return prices.quote(for: trade.symbol)?.price ?? bars.last?.close
    }

    var body: some View {
        ZStack {
            AppBackground()

            GeometryReader { proxy in
                VStack(spacing: 10) {
                    header

                    if let trade {
                        tradeCaption(trade)
                    } else {
                        symbolControls
                    }

                    GlassSegmented(
                        options: TVInterval.allCases,
                        selection: $interval,
                        label: { $0.title },
                        tint: { _ in Theme.blue }
                    )

                    chart
                        .frame(height: max(300, proxy.size.height - 214))

                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            guard selectedSymbol.isEmpty else { return }
            selectedSymbol = trade?.symbol ?? initialSymbol ?? symbols.first ?? "EURUSD"
        }
        .task(id: "\(symbol)|\(interval.rawValue)|\(isTradeMode)") {
            guard isTradeMode else { return }
            await loadBars()
        }
        .task(id: trade.map { "\($0.persistentModelID)" } ?? "none") {
            guard let trade, trade.result == .open else { return }
            await prices.refresh(symbols: [trade.symbol], force: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                if Task.isCancelled { break }
                await prices.refresh(symbols: [trade.symbol], force: true)
            }
        }
        .alert("Символ TradingView", isPresented: $showCustomSymbol) {
            TextField("FX:EURUSD", text: $customSymbol)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Открыть") { applyCustomSymbol() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Можно ввести тикер или полный символ, например OANDA:XAUUSD.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .glassCircle()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: isTradeMode ? "TradingView · сделка" : "Рынок")
                Text("TradingView")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 6)

            Link(destination: externalURL) {
                HStack(spacing: 5) {
                    Text("В приложении TV")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassCapsule()
            }
        }
    }

    // MARK: - Trade

    private func tradeCaption(_ trade: Trade) -> some View {
        HStack(spacing: 8) {
            Text(trade.symbol)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(trade.direction.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                )

            if trade.result != .open {
                Text(trade.result.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }

            Spacer(minLength: 6)

            Text("вход \(Fmt.price(trade.entry))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Instruments

    private var symbolControls: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { item in
                        Chip(
                            title: TradingViewSymbol.display(TradingViewSymbol.map(item)),
                            isSelected: selectedSymbol.caseInsensitiveCompare(item) == .orderedSame
                        ) {
                            selectedSymbol = item
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Menu {
                ForEach(symbols, id: \.self) { item in
                    Button {
                        selectedSymbol = item
                    } label: {
                        if selectedSymbol.caseInsensitiveCompare(item) == .orderedSame {
                            Label(TradingViewSymbol.display(TradingViewSymbol.map(item)), systemImage: "checkmark")
                        } else {
                            Text(TradingViewSymbol.display(TradingViewSymbol.map(item)))
                        }
                    }
                }
                Divider()
                Button("Другой символ…") {
                    customSymbol = ""
                    showCustomSymbol = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    private func applyCustomSymbol() {
        let value = customSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        selectedSymbol = value.uppercased()
        Haptics.success()
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        if isTradeMode {
            tradeChart
        } else {
            TradingViewChartView(symbol: tvSymbol, interval: interval.rawValue)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var tradeChart: some View {
        if isLoadingBars && bars.isEmpty {
            chartMessage {
                ProgressView()
                    .tint(Theme.textSecondary)
                Text("Загружаю свечи…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else if let barsError, bars.isEmpty {
            chartMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                Text(barsError)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Обновить") {
                    Task { await loadBars() }
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassCapsule()
            }
        } else if let trade {
            TradingViewLevelsChartView(
                symbol: trade.symbol,
                interval: interval.rawValue,
                bars: bars,
                levels: levels(for: trade),
                currentPrice: currentPrice
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private func chartMessage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 18)
    }

    private func levels(for trade: Trade) -> [TradingViewLevel] {
        var result: [TradingViewLevel] = [
            TradingViewLevel(price: trade.entry, title: "Вход", color: "FFFFFF", style: 0),
            TradingViewLevel(price: trade.originalStop, title: "Стоп", color: "FF8A8A", style: 0),
            TradingViewLevel(price: trade.takeProfit, title: "Тейк", color: "7BE3B0", style: 0)
        ]

        if let cycle = trade.cycle {
            for level in cycle.activeKeyLevels.prefix(6) {
                result.append(
                    TradingViewLevel(
                        price: level.price,
                        title: level.type.rawValue,
                        color: "BDBDBD",
                        style: 2
                    )
                )
            }
        }

        return result
    }

    private func loadBars() async {
        guard isTradeMode, !isLoadingBars else { return }
        isLoadingBars = true
        defer { isLoadingBars = false }

        do {
            let list = try await ChartDataService.candles(symbol: symbol, interval: interval)
            bars = list
            barsError = nil
        } catch {
            bars = []
            barsError = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось загрузить свечи."
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .semibold))
            Text(
                isTradeMode
                    ? "TradingView Lightweight Charts · вход белый, стоп красный, тейк зелёный, уровни дня серые"
                    : "Данные и инструменты TradingView · \(tvSymbol) · \(interval.title)"
            )
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(Theme.textTertiary)
    }
}

//
//  TradeMiniChartView.swift
//  ICT Checklist
//
//  Компактный график сделки: день входа или период удержания,
//  с отметками входа, стопа и тейка.
//

import SwiftUI
import Charts

struct TradeMiniChartView: View {
    let trade: Trade

    @State private var bars: [ChartBar] = []
    @State private var isLoading = false
    @State private var errorText: String?

    private var endDate: Date {
        trade.closedAt ?? .now
    }

    private var startDate: Date {
        Calendar.current.startOfDay(for: trade.entryDate)
    }

    private var holdingDays: Double {
        max(endDate.timeIntervalSince(trade.entryDate) / 86_400, 0)
    }

    private var interval: TVInterval {
        if holdingDays <= 2 { return .m15 }
        if holdingDays <= 10 { return .h1 }
        if holdingDays <= 45 { return .h4 }
        return .d1
    }

    private var periodText: String {
        let calendar = Calendar.current
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "день входа · \(Fmt.shortDay(startDate))"
        }
        return "\(Fmt.shortDay(startDate)) → \(Fmt.shortDay(endDate))"
    }

    private var taskKey: String {
        "\(trade.symbol)|\(trade.entryDate.timeIntervalSince1970)|\(trade.closedAt?.timeIntervalSince1970 ?? 0)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel(text: "График сделки")
                Spacer(minLength: 6)
                Text(periodText)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            content

            if !bars.isEmpty {
                HStack(spacing: 10) {
                    legendItem("Вход", value: trade.entry, tint: .white)
                    legendItem("Стоп", value: trade.originalStop, tint: Theme.red)
                    legendItem("Тейк", value: trade.takeProfit, tint: Theme.green)
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 22)
        .task(id: taskKey) {
            await loadBars()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && bars.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.textSecondary)
                Text("Загружаю свечи…")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(height: 120)
        } else if let errorText, bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                InfoHint(text: errorText, tint: Theme.textTertiary, icon: "chart.xyaxis.line")
                Button {
                    Task { await loadBars() }
                } label: {
                    Text("Повторить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        } else if bars.isEmpty {
            Text("Нет свечей за этот период")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 120)
        } else {
            MiniPriceChart(
                bars: bars,
                entry: trade.entry,
                stop: trade.originalStop,
                target: trade.takeProfit
            )
            .frame(height: 130)
        }
    }

    private func legendItem(_ title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
            Text(Fmt.price(value))
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    private func loadBars() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let all = try await ChartDataService.candles(
                symbol: trade.symbol,
                interval: interval,
                count: 300
            )
            bars = visibleBars(all)
            errorText = nil
        } catch {
            bars = []
            errorText = (error as? LocalizedError)?.errorDescription
                ?? "Не удалось загрузить свечи."
        }
    }

    private func visibleBars(_ all: [ChartBar]) -> [ChartBar] {
        let inPeriod = all.filter {
            let date = Date(timeIntervalSince1970: Double($0.time))
            return date >= startDate && date <= endDate
        }
        if inPeriod.count >= 6 {
            return inPeriod
        }
        return Array(all.suffix(30))
    }
}

// MARK: - Chart

private struct MiniPriceChart: View {
    let bars: [ChartBar]
    let entry: Double
    let stop: Double
    let target: Double

    private var lowerBound: Double {
        let lows = bars.map(\.low)
        let levels = [entry, stop, target]
        return min(lows.min() ?? 0, levels.min() ?? 0)
    }

    private var upperBound: Double {
        let highs = bars.map(\.high)
        let levels = [entry, stop, target]
        return max(highs.max() ?? 1, levels.max() ?? 1)
    }

    private var priceDomain: ClosedRange<Double> {
        let span = max(upperBound - lowerBound, 0.0001)
        return (lowerBound - span * 0.06)...(upperBound + span * 0.06)
    }

    private var firstDate: Date {
        Date(timeIntervalSince1970: Double(bars.first?.time ?? 0))
    }

    private var lastDate: Date {
        let date = Date(timeIntervalSince1970: Double(bars.last?.time ?? 0))
        return date > firstDate ? date : firstDate.addingTimeInterval(900)
    }

    private var candleWidth: CGFloat {
        let width = 220 / CGFloat(max(bars.count, 1))
        return min(max(width, 1), 4)
    }

    private func date(_ bar: ChartBar) -> Date {
        Date(timeIntervalSince1970: Double(bar.time))
    }

    var body: some View {
        Chart {
            ForEach(bars, id: \.time) { bar in
                RuleMark(
                    x: .value("Время", date(bar)),
                    yStart: .value("Low", bar.low),
                    yEnd: .value("High", bar.high)
                )
                .foregroundStyle(bar.close >= bar.open ? Theme.green : Theme.red)
                .lineStyle(StrokeStyle(lineWidth: 1))

                RectangleMark(
                    x: .value("Время", date(bar)),
                    yStart: .value("Open", min(bar.open, bar.close)),
                    yEnd: .value("Close", max(bar.open, bar.close)),
                    width: .fixed(candleWidth)
                )
                .foregroundStyle(bar.close >= bar.open ? Theme.green : Theme.red)
            }

            RuleMark(y: .value("Вход", entry))
                .foregroundStyle(Color.white)
                .lineStyle(StrokeStyle(lineWidth: 1))

            RuleMark(y: .value("Стоп", stop))
                .foregroundStyle(Theme.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            RuleMark(y: .value("Тейк", target))
                .foregroundStyle(Theme.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartXScale(domain: firstDate...lastDate)
        .chartYScale(domain: priceDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }
}

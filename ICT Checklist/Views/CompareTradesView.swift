//
//  CompareTradesView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct CompareTradesView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var first: Trade?
    @State private var second: Trade?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    topBar
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)

                    if trades.count < 2 {
                        notEnoughCard
                            .reveal(.rise, 1)
                    } else {
                        selectors
                            .reveal(.blur, 1)
                        columns
                            .reveal(.rise, 2)
                        Text("Сравнение ничего не меняет в сделках")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                            .reveal(.rise, 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .onAppear(perform: loadDefaults)
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .glassCircle()
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            SectionLabel(text: "Сделки")

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenTitle(text: "Сравнение")
            Text(headerSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        switch (first, second) {
        case let (first?, second?):
            return "\(label(for: first)) и \(label(for: second))"
        case let (first?, nil):
            return "\(label(for: first)) · выберите вторую сделку"
        case let (nil, second?):
            return "\(label(for: second)) · выберите первую сделку"
        case (nil, nil):
            return "Выберите две сделки из журнала"
        }
    }

    private func label(for trade: Trade) -> String {
        "\(trade.symbol) \(trade.direction.rawValue.lowercased()) · \(Fmt.shortDay(trade.tradingDay))"
    }

    // MARK: - Selectors

    private var selectors: some View {
        HStack(spacing: 8) {
            selector(title: "Сделка 1", trade: first, other: second) { first = $0 }
            selector(title: "Сделка 2", trade: second, other: first) { second = $0 }
        }
    }

    private func selector(
        title: String,
        trade: Trade?,
        other: Trade?,
        onSelect: @escaping (Trade) -> Void
    ) -> some View {
        Menu {
            ForEach(trades.filter { $0.persistentModelID != other?.persistentModelID }) { item in
                Button("\(item.symbol) · \(Fmt.shortDay(item.tradingDay))") {
                    onSelect(item)
                    Haptics.select()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)

                HStack(spacing: 6) {
                    Text(trade.map { "\($0.symbol) · \(Fmt.shortDay($0.tradingDay))" } ?? "Выберите")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(trade == nil ? Theme.textSecondary : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Columns

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            column(first, placeholder: "Выберите первую сделку")

            Color.clear
                .frame(width: 62)

            column(second, placeholder: "Выберите вторую сделку")
        }
        .overlay {
            differenceView
                .frame(width: 62)
        }
    }

    private func column(_ trade: Trade?, placeholder: String) -> some View {
        Group {
            if let trade {
                TradeCompareColumn(trade: trade)
            } else {
                Text(placeholder)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .padding(12)
                    .glassCard(cornerRadius: 20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var differenceText: String {
        guard let first, let second else { return "—" }
        return Fmt.r(first.actualR - second.actualR)
    }

    private var differenceTint: Color {
        guard let first, let second else { return Theme.textTertiary }
        let diff = first.actualR - second.actualR
        if diff > 0.05 { return Theme.green }
        if diff < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private var differenceView: some View {
        VStack(spacing: 4) {
            Text("Разница R")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)

            Text(differenceText)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(differenceTint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private var notEnoughCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сравнивать пока нечего")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Для сравнения нужно хотя бы две сделки в журнале.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func loadDefaults() {
        if first == nil { first = trades.first }
        if second == nil {
            second = trades.first { $0.persistentModelID != first?.persistentModelID }
        }
    }
}

// MARK: - Column

private struct TradeCompareColumn: View {
    let trade: Trade

    private var resultText: String {
        trade.result == .open ? "Открыта" : trade.result.rawValue
    }

    private var resultTint: Color {
        switch trade.result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.textSecondary
        case .open: return Theme.textTertiary
        }
    }

    private var rText: String {
        trade.result == .open ? "—" : Fmt.r(trade.actualR)
    }

    private var rTint: Color {
        if trade.result == .open { return Theme.textTertiary }
        if trade.actualR > 0.05 { return Theme.green }
        if trade.actualR < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private var zoneText: String {
        trade.cycle?.zone?.rawValue ?? "—"
    }

    private var trendText: String {
        trade.cycle?.trendType.rawValue ?? "—"
    }

    private var levelsText: String {
        guard let cycle = trade.cycle else { return "—" }
        let types = Set(cycle.keyLevels.map { $0.type.rawValue }).sorted()
        return types.isEmpty ? "—" : types.joined(separator: ", ")
    }

    private var confirmationsText: String {
        guard let cycle = trade.cycle else { return "—" }
        return "\(cycle.confirmations.count) из \(ConfirmationKey.allCases.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trade.symbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(trade.direction.rawValue)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                )
                .padding(.top, 4)
                .padding(.bottom, 6)

            row("Entry", Fmt.price(trade.entry))
            row("SL", Fmt.price(trade.originalStop))
            row("TP", Fmt.price(trade.takeProfit))
            row("RR", String(format: "%.1f", trade.plannedRR))
            row("Ступень", "\(trade.ladderStepIndex + 1) · \(Fmt.money(trade.riskUSD))")
            row("Результат", resultText, tint: resultTint)
            row("R", rText, tint: rTint)

            divider

            Text("Метки")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)

            if trade.tags.isEmpty {
                Text("—")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(trade.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Capsule().fill(Color.white.opacity(0.09)))
                    }
                }
            }

            divider

            Text("Элементы входа")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)

            element("square.dashed", "Зона", zoneText)
            element(trade.direction == .long ? "arrow.up" : "arrow.down", "Тренд", trendText)
            element("line.3.horizontal", "Уровни", levelsText)
            element("chart.bar", "Подтверждения", confirmationsText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 20)
    }

    private var divider: some View {
        Divider()
            .overlay(Theme.hairline)
            .padding(.vertical, 8)
    }

    private func row(_ title: String, _ value: String, tint: Color = Theme.textPrimary) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.vertical, 4)
    }

    private func element(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18, height: 18)
                .glassCircle()

            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.vertical, 3)
    }
}

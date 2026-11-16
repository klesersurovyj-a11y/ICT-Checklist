//
//  EntrySteps.swift
//  ICT Checklist
//

import SwiftUI

// MARK: - Symbol

struct SymbolStep: View {
    @Bindable var cycle: TradingCycle
    let settings: AppSettings?

    private var symbols: [String] {
        let list = settings?.symbols ?? []
        return list.isEmpty ? ["EURUSD", "GBPUSD", "XAUUSD"] : list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    choose(symbol)
                } label: {
                    HStack(spacing: 12) {
                        Text(symbol)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer(minLength: 4)
                        Text(cycle.direction.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(cycle.direction == .long ? Theme.green : Theme.red)
                        if cycle.symbol == symbol {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.blue)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(cycle.symbol == symbol ? Theme.blue.opacity(0.14) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                cycle.symbol == symbol ? Theme.blue.opacity(0.5) : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            InfoHint(text: "Риск на сделку — \(Fmt.money(cycle.riskUSD)), ступень \(cycle.ladderStepIndex + 1).")
        }
    }

    private func choose(_ symbol: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cycle.symbol = symbol
        }
        Haptics.select()
    }
}

// MARK: - RR

struct RRStep: View {
    @Bindable var cycle: TradingCycle
    let minRR: Double

    private var rrColor: Color {
        guard let rr = cycle.computedRR else { return Theme.textSecondary }
        return rr >= minRR ? Theme.green : Theme.red
    }

    private var verdict: String {
        guard let rr = cycle.computedRR else { return "—" }
        return rr >= minRR ? "вход разрешён" : "ниже минимума"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PriceField(title: "Entry", placeholder: "Цена входа", value: $cycle.entryPrice)
            PriceField(title: "SL — за Point A", placeholder: "Стоп за A", value: $cycle.stopPrice)
            PriceField(title: "TP — Point B", placeholder: "Цель на B", value: $cycle.takeProfit)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RR")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.rr(cycle.computedRR))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(rrColor)
                }
                Spacer(minLength: 4)
                Text(verdict)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(rrColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(rrColor.opacity(0.14)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )

            if let rr = cycle.computedRR, rr < minRR {
                InfoHint(
                    text: "RR ниже минимума \(Fmt.rr(minRR)). Входа нет. Если цена изменится и RR станет достаточным при валидных A и B — вход снова возможен.",
                    tint: Theme.orange,
                    icon: "exclamationmark.triangle"
                )
            } else if !cycle.pointAValid || !cycle.pointBValid {
                InfoHint(
                    text: "Сценарий недействителен: A или B потеряли валидность. RR не может его восстановить.",
                    tint: Theme.red,
                    icon: "xmark.octagon"
                )
            } else {
                InfoHint(text: "Минимальный RR — \(Fmt.rr(minRR)). SL не двигается, TP не двигается, частичных закрытий нет.")
            }
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        if cycle.stopPrice == nil, let a = cycle.pointAPrice {
            cycle.stopPrice = a
        }
        if cycle.takeProfit == nil, let b = cycle.pointBPrice {
            cycle.takeProfit = b
        }
    }
}

// MARK: - Entry

struct EntryStep: View {
    let cycle: TradingCycle

    private var items: [SummaryItem] {
        [
            SummaryItem(title: "Символ", value: cycle.symbol),
            SummaryItem(
                title: "Направление",
                value: cycle.direction.rawValue,
                tint: cycle.direction == .long ? Theme.green : Theme.red
            ),
            SummaryItem(title: "Entry", value: Fmt.price(cycle.entryPrice)),
            SummaryItem(title: "SL", value: Fmt.price(cycle.stopPrice), tint: Theme.red),
            SummaryItem(title: "TP", value: Fmt.price(cycle.takeProfit), tint: Theme.green),
            SummaryItem(title: "RR", value: Fmt.rr(cycle.computedRR), tint: Theme.blue),
            SummaryItem(title: "Риск", value: Fmt.money(cycle.riskUSD), tint: Theme.orange)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SummaryTable(items: items)

            if !cycle.pointAValid || !cycle.pointBValid {
                InfoHint(
                    text: "Сценарий потерял валидность. Вход по нему не выполняется.",
                    tint: Theme.red,
                    icon: "xmark.octagon"
                )
            }

            InfoHint(text: "После входа SL и TP не двигаются, partial close нет. Закройте терминал и поставьте уведомления на TP и SL.")
        }
    }
}

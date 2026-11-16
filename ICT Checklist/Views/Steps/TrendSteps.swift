//
//  TrendSteps.swift
//  ICT Checklist
//

import SwiftUI

// MARK: - OF / SOF

struct TrendTypeStep: View {
    @Bindable var cycle: TradingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSegmented(
                options: TrendType.allCases,
                selection: Binding(
                    get: { cycle.trendType },
                    set: { cycle.trendType = $0 }
                ),
                label: { $0.rawValue }
            )
            InfoHint(text: cycle.trendType.explain)
            InfoHint(text: "Направление недельного тренда фиксируется на следующем шаге.")
        }
    }
}

// MARK: - Trend W1

struct TrendStep: View {
    @Bindable var cycle: TradingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSegmented(
                options: Direction.allCases,
                selection: Binding(
                    get: { cycle.direction },
                    set: { cycle.direction = $0 }
                ),
                label: { $0.rawValue },
                tint: { $0 == .long ? Theme.green : Theme.red }
            )

            HStack(spacing: 8) {
                Text(cycle.trendType.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.blue.opacity(0.14)))
                Text("Направление недельного графика")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }

            GlassNoteField(placeholder: "Где OF, где SOF, что ждём…", text: $cycle.trendNote)

            InfoHint(
                text: cycle.direction == .long
                    ? "Для LONG работаем в Discount."
                    : "Для SHORT работаем в Premium."
            )
        }
    }
}

// MARK: - Last DR

struct DRStep: View {
    @Bindable var cycle: TradingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PriceField(title: "Верхняя граница", placeholder: "Например 1.0925", value: $cycle.drHigh)
            PriceField(title: "Нижняя граница", placeholder: "Например 1.0780", value: $cycle.drLow)

            if let mid = cycle.drMid {
                HStack {
                    Text("0.5 DR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(Fmt.price(mid))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.orange)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }

            InfoHint(text: "DR — последний сформированный актуальный диапазон. Верхняя граница должна быть выше нижней.")
        }
    }
}

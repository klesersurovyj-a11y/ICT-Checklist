//
//  TradeChecklistCard.swift
//  ICT Checklist
//
//  Чек-лист конкретной сделки: применяется к входу, а не к каждому дню.
//

import SwiftUI

struct TradeChecklistCard: View {
    let checks: Set<TradeCheck>
    let toggle: (TradeCheck) -> Void
    var caption: String = "Отмечайте пункты под конкретную сделку, а не каждый день."

    private var isComplete: Bool {
        checks.count == TradeCheck.allCases.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel(text: "Чек-лист сделки")
                Spacer(minLength: 6)
                Text("\(checks.count)/\(TradeCheck.allCases.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isComplete ? Theme.green : Theme.textTertiary)
                Text(isComplete ? "ПО СИСТЕМЕ" : "НЕ ЗАКРЫТ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(isComplete ? Theme.green : Theme.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill((isComplete ? Theme.green : Theme.orange).opacity(0.14)))
            }

            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 2) {
                ForEach(TradeCheck.allCases) { item in
                    row(item)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private func row(_ item: TradeCheck) -> some View {
        let done = checks.contains(item)
        return Button {
            toggle(item)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(done ? Theme.green : Theme.textTertiary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

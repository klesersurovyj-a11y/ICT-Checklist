//
//  DayResultView.swift
//  ICT Checklist
//

import SwiftUI

struct DayResultView: View {
    let cycle: TradingCycle
    var onDone: (() -> Void)? = nil

    @Environment(\.modelContext) private var context

    private var directionColor: Color {
        cycle.direction == .long ? Theme.green : Theme.red
    }

    private var items: [SummaryItem] {
        var rows: [SummaryItem] = [
            SummaryItem(title: "Символ", value: cycle.symbol),
            SummaryItem(title: "Направление", value: cycle.direction.rawValue, tint: directionColor),
            SummaryItem(title: "Entry", value: Fmt.price(cycle.entryPrice)),
            SummaryItem(title: "SL", value: Fmt.price(cycle.stopPrice), tint: Theme.red),
            SummaryItem(title: "TP", value: Fmt.price(cycle.takeProfit), tint: Theme.green),
            SummaryItem(title: "RR", value: Fmt.rr(cycle.computedRR), tint: Theme.blue),
            SummaryItem(title: "Риск", value: Fmt.money(cycle.riskUSD), tint: Theme.orange)
        ]
        if let trade = cycle.trade {
            rows.insert(SummaryItem(title: "Время входа", value: Fmt.time(trade.entryDate)), at: 2)
            if trade.result != .open {
                rows.append(SummaryItem(title: "Результат", value: trade.result.rawValue, tint: statusColor))
                rows.append(SummaryItem(title: "Факт R", value: Fmt.r(trade.actualR), tint: rTint(trade.actualR)))
            }
        }
        return rows
    }

    private var tradeResult: TradeResult? {
        guard let trade = cycle.trade, trade.result != .open else { return nil }
        return trade.result
    }

    private var statusColor: Color {
        if cycle.stopDay { return Theme.red }
        guard let result = tradeResult else { return Theme.green }
        switch result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return Theme.green
        }
    }

    private var statusIcon: String {
        if cycle.stopDay { return "exclamationmark.octagon.fill" }
        guard let result = tradeResult else { return "checkmark.seal.fill" }
        switch result {
        case .tp: return "checkmark.seal.fill"
        case .sl: return "xmark.octagon.fill"
        case .be: return "minus.circle.fill"
        case .open: return "checkmark.seal.fill"
        }
    }

    private var statusEyebrow: String {
        if cycle.stopDay { return "STOP DAY" }
        guard let result = tradeResult else { return "СДЕЛКА ОТКРЫТА" }
        switch result {
        case .tp: return "TP · СДЕЛКА ЗАКРЫТА"
        case .sl: return "SL · СДЕЛКА ЗАКРЫТА"
        case .be: return "BE · СДЕЛКА ЗАКРЫТА"
        case .open: return "СДЕЛКА ОТКРЫТА"
        }
    }

    private var statusText: String {
        if cycle.stopDay {
            return "SL — новых входов в этот торговый день нет. Следующий цикл в 19:00."
        }
        guard let result = tradeResult else {
            return "Позиция открыта до TP или SL. Дальше управлять нечем — только ждать."
        }
        let actualR = cycle.trade?.actualR ?? 0
        switch result {
        case .tp: return "Позиция закрыта по TP: \(Fmt.r(actualR))."
        case .sl: return "Позиция закрыта по SL: \(Fmt.r(actualR))."
        case .be: return "Позиция закрыта в BE: 0R."
        case .open: return "Позиция открыта до TP или SL."
        }
    }

    private func rTint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(statusColor)
                    Text(statusEyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(statusColor)
                    Spacer(minLength: 0)
                }
                Text("Итог дня")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SummaryTable(items: items)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(cornerRadius: 28)

            RouteMapView()

            tpOutcomeCard

            InfoHint(text: "SL и TP не двигаются, ручного управления нет. Закройте терминал и поставьте уведомления на TP и SL.")
            InfoHint(
                text: "SL → STOP DAY: новых входов в этот день нет. BE-позиции прошлых дней живут отдельно и новый цикл не блокируют.",
                tint: Theme.textTertiary
            )

            if let onDone {
                SecondaryButton(title: "К экрану «Сегодня»", action: onDone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - TP outcome

    @ViewBuilder
    private var tpOutcomeCard: some View {
        if cycle.trade?.result == .tp {
            VStack(alignment: .leading, spacing: 14) {
                Text("B дал объём?")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if cycle.tpVolumeAnswered {
                    InfoHint(
                        text: cycle.tpVolumeGiven ? ideaCompleteText : deliveryText,
                        tint: cycle.tpVolumeGiven ? Theme.green : Theme.orange,
                        icon: cycle.tpVolumeGiven ? "checkmark.circle" : "arrow.triangle.2.circlepath"
                    )
                    Button {
                        cycle.tpVolumeAnswered = false
                        try? context.save()
                    } label: {
                        Text("Изменить ответ")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 10) {
                        outcomeButton(
                            "Да, дал объём",
                            tint: Theme.green,
                            given: true
                        )
                        outcomeButton(
                            "Нет, слабая коррекция",
                            tint: Theme.orange,
                            given: false
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(cornerRadius: 26)
        }
    }

    private var ideaCompleteText: String {
        "Идея завершена. Не ищем следующую идею сразу: ждём поглощения последнего актуального DR → NEW TREND → NEW DR → новые Key Levels → новый цикл."
    }

    private var deliveryText: String {
        "Delivery continues. Ждём новый вход: тот же A валиден и появился новый Entry — новая сделка в той же идее; появился новый A — новый B и новая идея."
    }

    private func outcomeButton(_ title: String, tint: Color, given: Bool) -> some View {
        Button {
            answer(given)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func answer(_ given: Bool) {
        cycle.tpVolumeAnswered = true
        cycle.tpVolumeGiven = given
        cycle.trade?.volumeFromB = given
        try? context.save()
        Haptics.success()
    }
}

struct RouteMapView: View {
    var currentIndex: Int? = nil

    private let nodes = [
        "19:00", "NEWS", "RISK", "OF/SOF", "TREND", "LAST DR",
        "P/D", "KL", "POINT A", "POINT B", "TEST A", "REACTION",
        "SLOWDOWN", "FRACTALS", "SNR", "TEST", "RR", "ENTRY", "SL / TP"
    ]

    private var entryIndex: Int {
        nodes.firstIndex(of: "ENTRY") ?? 0
    }

    private var resolvedCurrent: Int {
        currentIndex ?? entryIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("МАРШРУТ ДНЯ")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                        pill(node, index: index)
                        if index < nodes.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                branchChip("SL → STOP DAY", tint: Theme.red)
                branchChip("TP → B дал объём?", tint: Theme.green)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func pill(_ node: String, index: Int) -> some View {
        let isCurrent = index == resolvedCurrent
        let isDone = index < resolvedCurrent
        return Text(node)
            .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
            .foregroundStyle(isCurrent || isDone ? .white : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isCurrent ? Theme.blue : (isDone ? Theme.blue.opacity(0.28) : Color.white.opacity(0.06))
                )
            )
    }

    private func branchChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }
}

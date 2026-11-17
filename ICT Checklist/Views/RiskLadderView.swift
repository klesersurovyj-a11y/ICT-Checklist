//
//  RiskLadderView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct RiskLadderView: View {
    @Environment(\.modelContext) private var context

    @Query private var trades: [Trade]
    @Query private var settingsList: [AppSettings]

    private let cardHeight: CGFloat = 92
    private let cardGap: CGFloat = 12

    private var stride: CGFloat { cardHeight + cardGap }
    private var stackHeight: CGFloat { cardHeight * 3 + cardGap * 2 }

    private var settings: AppSettings? { settingsList.first }
    private var amounts: [Double] {
        let list = settings?.ladderAmounts ?? []
        return list.count == 3 ? list : [12, 25, 50]
    }

    private var snapshot: LadderSnapshot { LadderEngine.evaluate(trades: trades) }
    private var stepIndex: Int { min(max(snapshot.stepIndex, 0), 2) }
    private var currentAmount: Double { amounts[stepIndex] }
    private var nextAmount: Double? { stepIndex < 2 ? amounts[stepIndex + 1] : nil }
    private var accumulated: Double { snapshot.accumulatedR }
    private var progress: Double {
        min(max(accumulated / LadderSnapshot.targetR, 0), 1)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .reveal(.slideLeft)
                    heroCard
                        .reveal(.zoom, 1)
                    ladder
                        .reveal(.tilt, 2)
                    howItWorks
                        .reveal(.rise, 3)
                    history
                        .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .task { LadderEngine.sync(context: context) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Непрерывно с запуска")
            ScreenTitle(text: "Risk Ladder")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("СЛЕДУЮЩАЯ СДЕЛКА")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.money(currentAmount))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Ступень \(stepIndex + 1) из 3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
            }
            Spacer(minLength: 0)
            ring
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var ring: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                Text("\(String(format: "%.1f", accumulated)) / 2.0 R")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 8)
            }
            .frame(width: 112, height: 112)

            Text(nextAmount.map { "до \(Fmt.money($0))" } ?? "потолок")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.orange)
        }
    }

    // MARK: - Ladder

    private var ladder: some View {
        let order = Array((0..<3).reversed())

        return ZStack(alignment: .topLeading) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 2, height: stackHeight - cardHeight)
                .offset(x: 12, y: cardHeight / 2)

            Capsule()
                .fill(Theme.blue.opacity(0.85))
                .frame(width: 2, height: max(0, CGFloat(2 - stepIndex) * stride))
                .offset(x: 12, y: cardHeight / 2)

            VStack(spacing: cardGap) {
                ForEach(order, id: \.self) { index in
                    HStack(spacing: 0) {
                        railDot(isCurrent: index == stepIndex)
                            .frame(width: 26, height: cardHeight)
                        stepCard(index)
                    }
                }
            }
        }
    }

    private func railDot(isCurrent: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Theme.blue.opacity(0.4))
                .frame(width: 30, height: 30)
                .blur(radius: 8)
                .opacity(isCurrent ? 1 : 0)
            Circle()
                .fill(isCurrent ? Theme.blue : Color(hex: 0x2A3444))
                .frame(width: isCurrent ? 16 : 12, height: isCurrent ? 16 : 12)
                .overlay(
                    Circle().strokeBorder(
                        Color.white.opacity(isCurrent ? 0.75 : 0.18),
                        lineWidth: isCurrent ? 2 : 1
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stepCard(_ index: Int) -> some View {
        let isCurrent = index == stepIndex
        let isCeiling = index == LadderSnapshot.lastStepIndex

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(Fmt.money(amounts[index]))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(isCurrent ? .white : Theme.textPrimary.opacity(0.85))
                    if isCurrent {
                        badge("СЕЙЧАС", tint: Theme.blue)
                    } else if isCeiling {
                        badge("МАКС", tint: Color.white.opacity(0.55))
                    }
                }
                Text("Ступень \(index + 1) · \(roleWord(index))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text("+2R → \(Fmt.money(amounts[min(index + 1, 2)]))")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(isCeiling ? "TP → остаёмся" : "SL → \(Fmt.money(amounts[0]))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(height: cardHeight)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isCurrent ? Theme.blue.opacity(0.14) : Theme.glassTint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(isCurrent ? Theme.blue : Theme.glassStroke, lineWidth: isCurrent ? 1.5 : 1)
                }
        }
        .shadow(
            color: isCurrent ? Theme.blue.opacity(0.45) : Color.black.opacity(0.25),
            radius: isCurrent ? 18 : 12,
            x: 0,
            y: isCurrent ? 0 : 8
        )
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.18)))
    }

    private func roleWord(_ index: Int) -> String {
        if index == stepIndex { return "текущая" }
        if index == LadderSnapshot.lastStepIndex { return "потолок" }
        if index == 0 { return "старт" }
        return "средняя"
    }

    // MARK: - Rules

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Как это работает")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ruleRow(icon: "arrow.up", tint: Theme.green, text: "+2R внутри ступени — переход выше, счёт обнуляется")
            Divider().overlay(Color.white.opacity(0.06))
            ruleRow(
                icon: "arrow.down",
                tint: Theme.orange,
                text: "SL — ступень вниз или остаёмся на \(Fmt.money(amounts[0]))"
            )
            Divider().overlay(Color.white.opacity(0.06))
            ruleRow(icon: "calendar", tint: Theme.blue, text: "Смена дня не сбрасывает лестницу")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private func ruleRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - History

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ИСТОРИЯ ПЕРЕХОДОВ")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            if snapshot.events.isEmpty {
                Text("Переходов пока нет — первый появится после закрытых сделок.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let recent = Array(snapshot.events.suffix(6).reversed())
                VStack(spacing: 12) {
                    ForEach(recent) { event in
                        historyRow(event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private func historyRow(_ event: LadderSnapshot.Event) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(event.isUp ? Theme.green : Theme.red)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill((event.isUp ? Theme.green : Theme.red).opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(stepTransition(event))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(event.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(Fmt.shortDay(event.date))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func stepTransition(_ event: LadderSnapshot.Event) -> String {
        if event.fromStep == event.toStep {
            return "Ступень \(event.fromStep + 1) · потолок"
        }
        return "Ступень \(event.fromStep + 1) → Ступень \(event.toStep + 1)"
    }
}

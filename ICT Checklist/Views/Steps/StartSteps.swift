//
//  StartSteps.swift
//  ICT Checklist
//

import SwiftUI

// MARK: - News

struct NewsStep: View {
    @Bindable var cycle: TradingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                CurrencyRow(code: "EUR", name: "Евро", isOn: $cycle.newsEUR)
                CurrencyRow(code: "GBP", name: "Фунт", isOn: $cycle.newsGBP)
                CurrencyRow(code: "USD", name: "Доллар", isOn: $cycle.newsUSD)
            }
            GlassNoteField(placeholder: "Что по новостям и когда…", text: $cycle.newsNote)
            InfoHint(text: "Отмечайте «важно», если новость может сдвинуть цену в окне 19:00–22:00.")
        }
    }
}

struct CurrencyRow: View {
    let code: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(code)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isOn ? .white : Theme.textSecondary)
                .frame(width: 46, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? Theme.blue.opacity(0.9) : Color.white.opacity(0.07))
                )
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                segment("важно", active: isOn) { set(true) }
                segment("нет", active: !isOn) { set(false) }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func set(_ value: Bool) {
        guard isOn != value else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isOn = value
        }
        Haptics.select()
    }

    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? .white : Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    if active {
                        Capsule().fill(isOn ? Theme.blue.opacity(0.75) : Color.white.opacity(0.14))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk

struct RiskStep: View {
    @Bindable var cycle: TradingCycle
    let ladder: RiskLadderState?
    let settings: AppSettings?

    private var stepIndex: Int {
        min(max(ladder?.stepIndex ?? cycle.ladderStepIndex, 0), 2)
    }

    private var amount: Double {
        settings?.ladderAmount(at: stepIndex) ?? cycle.riskUSD
    }

    private var accumulated: Double {
        ladder?.accumulatedR ?? cycle.accumulatedR
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("СТУПЕНЬ \(stepIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.orange)
                    Text(Fmt.money(amount))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("риск на следующую сделку")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("НАКОПЛЕНО")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.r(accumulated))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(accumulated >= 0 ? Theme.green : Theme.red)
                    Text("до следующей ступени")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    ladderPill(index)
                }
            }

            Button {
                sync()
                Haptics.tap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Подтянуть из Risk Ladder")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.blue.opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            InfoHint(text: "Risk Ladder непрерывна: ступень подтягивается из общего состояния и не сбрасывается каждый день.")
        }
        .onAppear { sync() }
    }

    private func ladderPill(_ index: Int) -> some View {
        let active = index == stepIndex
        return VStack(spacing: 3) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(active ? Theme.orange : Theme.textTertiary)
            Text(Fmt.money(settings?.ladderAmount(at: index) ?? 0))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? .white : Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? Theme.orange.opacity(0.16) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(active ? Theme.orange.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func sync() {
        let index = min(max(ladder?.stepIndex ?? cycle.ladderStepIndex, 0), 2)
        cycle.ladderStepIndex = index
        cycle.riskUSD = settings?.ladderAmount(at: index) ?? cycle.riskUSD
        cycle.accumulatedR = ladder?.accumulatedR ?? cycle.accumulatedR
    }
}

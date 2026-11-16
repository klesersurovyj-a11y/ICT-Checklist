//
//  StepCardView.swift
//  ICT Checklist
//

import SwiftUI

struct StepCardView: View {
    let cycle: TradingCycle
    let step: CycleStep
    let ladder: RiskLadderState?
    let settings: AppSettings?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ШАГ \(String(format: "%02d", step.number))")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.accent)
                Text(step.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .news:
            NewsStep(cycle: cycle)
        case .risk:
            RiskStep(cycle: cycle, ladder: ladder, settings: settings)
        case .ofsof:
            TrendTypeStep(cycle: cycle)
        case .trendW1:
            TrendStep(cycle: cycle)
        case .lastDR:
            DRStep(cycle: cycle)
        case .premiumDiscount:
            PremiumDiscountStep(cycle: cycle)
        case .keyLevels:
            KeyLevelsStep(cycle: cycle)
        case .keyLevelToPointA:
            KeyLevelToPointAStep(cycle: cycle)
        case .pointA:
            PointAStep(cycle: cycle)
        case .pointB:
            PointBStep(cycle: cycle)
        case .testA, .reaction, .slowdown, .fractals, .snr, .test:
            if let key = step.confirmationKey {
                ConfirmationStep(cycle: cycle, key: key)
            }
        case .symbol:
            SymbolStep(cycle: cycle, settings: settings)
        case .rr:
            RRStep(cycle: cycle, minRR: settings?.minRR ?? 2.0)
        case .entry:
            EntryStep(cycle: cycle)
        }
    }
}

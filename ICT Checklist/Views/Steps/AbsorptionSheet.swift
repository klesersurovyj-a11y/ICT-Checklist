//
//  AbsorptionSheet.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct AbsorptionSheet: View {
    let level: KeyLevel

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isFilled = false
    @State private var hasCounterOF = false
    @State private var simpleCondition = false

    private var type: KeyLevelType { level.type }

    private var canConfirm: Bool {
        switch type {
        case .fvg:
            return isFilled && hasCounterOF
        default:
            return simpleCondition
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Поглощение \(type.rawValue)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(Fmt.price(level.price)) · условие полного поглощения")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 8) {
                conditions
            }

            PrimaryButton(title: "Поглощён", icon: "checkmark", isEnabled: canConfirm) {
                confirm()
            }

            Text("Уровень уйдёт из активного списка. Инвалидация сценария A/B его не удаляет — KL удаляется только при полном поглощении.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    @ViewBuilder
    private var conditions: some View {
        switch type {
        case .fvg:
            CheckRow(title: "FVG полностью заполнен", isOn: $isFilled)
            CheckRow(title: "Есть текущий Counter OF", isOn: $hasCounterOF)
        case .snr:
            CheckRow(title: "SNR поглощён", isOn: $simpleCondition)
        case .fractal:
            CheckRow(title: "Цена достигла другого Key Level", isOn: $simpleCondition)
        case .halfDR:
            CheckRow(title: "DR инвалидирован", isOn: $simpleCondition)
        }
    }

    private func confirm() {
        guard canConfirm else { return }
        level.absorbed = true
        level.isWorking = false
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

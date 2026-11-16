//
//  ZoneSteps.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

// MARK: - Premium / Discount

struct PremiumDiscountStep: View {
    @Bindable var cycle: TradingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let high = cycle.drHigh, let low = cycle.drLow, let mid = cycle.drMid {
                HStack(spacing: 8) {
                    MetricTile(title: "0.5 DR", value: Fmt.price(mid), tint: Theme.orange)
                    MetricTile(title: "Верх DR", value: Fmt.price(high))
                    MetricTile(title: "Низ DR", value: Fmt.price(low))
                }

                PriceField(title: "Текущая цена", placeholder: "Например 1.0812", value: $cycle.currentPrice)

                if let price = cycle.currentPrice, price > 0 {
                    ZoneBar(low: low, high: high, price: price)
                }

                zoneVerdict
            } else {
                InfoHint(
                    text: "Сначала заполните границы DR на предыдущем шаге.",
                    tint: Theme.orange,
                    icon: "exclamationmark.triangle"
                )
            }
        }
    }

    @ViewBuilder
    private var zoneVerdict: some View {
        if let zone = cycle.zone, let price = cycle.currentPrice, price > 0 {
            if cycle.zoneMismatch {
                InfoHint(
                    text: "Цена в зоне \(zone.rawValue). Для \(cycle.direction.rawValue) работаем в \(cycle.direction.expectedZone.rawValue). Проверьте зону или направление.",
                    tint: Theme.orange,
                    icon: "exclamationmark.triangle"
                )
            } else {
                InfoHint(
                    text: "Зона в порядке: \(zone.rawValue) — для \(cycle.direction.rawValue) это правильная рабочая зона.",
                    tint: Theme.green,
                    icon: "checkmark.circle"
                )
            }
        }
    }
}

// MARK: - Key Levels

struct KeyLevelsStep: View {
    @Bindable var cycle: TradingCycle

    @Environment(\.modelContext) private var context

    @State private var newType: KeyLevelType = .snr
    @State private var newPrice: Double?
    @State private var newNote: String = ""
    @State private var absorbingLevel: KeyLevel?

    private var reference: Double? { cycle.referencePrice }

    private var canAdd: Bool { (newPrice ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(cycle.activeKeyLevels.count) активных")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                if let reference {
                    Text("цена \(Fmt.price(reference))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if cycle.activeKeyLevels.isEmpty, cycle.drMid != nil {
                waitingCard
            }

            addForm
            levelsList

            InfoHint(text: "Уровни сортируются от ближайшего к цене к самому дальнему. Поглощённые уровни уходят из активного списка.")
        }
        .sheet(item: $absorbingLevel) { level in
            AbsorptionSheet(level: level)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KeyLevelType.allCases) { type in
                        Chip(title: type.rawValue, isSelected: newType == type, tint: type.tint) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                newType = type
                            }
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack(alignment: .bottom, spacing: 10) {
                PriceField(title: "Цена уровня", placeholder: "0.0000", value: $newPrice)
                Button {
                    addLevel()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 51)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(canAdd ? Theme.blue : Theme.blue.opacity(0.3))
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canAdd)
            }

            GlassNoteField(placeholder: "Заметка к уровню…", text: $newNote, limit: 120, lines: 1...2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var levelsList: some View {
        VStack(spacing: 8) {
            if cycle.activeKeyLevels.isEmpty {
                Text("Активных уровней нет — добавьте первый Key Level.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(cycle.sortedKeyLevels) { level in
                    levelRow(level)
                }
            }

            let absorbedCount = cycle.keyLevels.filter { $0.absorbed }.count
            if absorbedCount > 0 {
                Text("Поглощено: \(absorbedCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func levelRow(_ level: KeyLevel) -> some View {
        HStack(spacing: 10) {
            Text(level.type.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(level.type.tint.opacity(0.85)))

            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.price(level.price))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !level.note.isEmpty {
                    Text(level.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if let reference, reference > 0 {
                Text(Fmt.distancePercent(level.price, from: reference))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            Button {
                absorbingLevel = level
                Haptics.tap()
            } label: {
                Text("Поглощён")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.red.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(Theme.red.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func addLevel() {
        guard let price = newPrice, price > 0 else { return }
        let level = KeyLevel(
            type: newType,
            price: price,
            note: newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(level)
        cycle.keyLevels.append(level)
        cycle.updatedAt = .now
        newPrice = nil
        newNote = ""
        try? context.save()
        Haptics.success()
    }

    private func absorb(_ level: KeyLevel) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            level.absorbed = true
            level.isWorking = false
        }
        cycle.updatedAt = .now
        try? context.save()
        Haptics.tap()
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ждём формирования нового KL")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Актуальный DR ещё держится. Новый Key Level сразу станет кандидатом на Point A, если появится в рабочей зоне.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.blue.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Key Level → Point A

struct KeyLevelToPointAStep: View {
    @Bindable var cycle: TradingCycle

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if cycle.activeKeyLevels.isEmpty {
                InfoHint(
                    text: "Нет активных Key Level. Вернитесь на шаг KL и добавьте уровни.",
                    tint: Theme.orange,
                    icon: "exclamationmark.triangle"
                )
            } else {
                workingCard
                selectionRow

                VStack(spacing: 8) {
                    CheckRow(
                        title: "SNR на Key Level",
                        isOn: Binding(get: { cycle.aConditionSNR }, set: { cycle.aConditionSNR = $0 })
                    )
                    CheckRow(
                        title: "Нарушение OF, который доставлял цену",
                        isOn: Binding(get: { cycle.aConditionOF }, set: { cycle.aConditionOF = $0 })
                    )
                    CheckRow(
                        title: "Fractal",
                        isOn: Binding(get: { cycle.aConditionFractal }, set: { cycle.aConditionFractal = $0 })
                    )
                }

                resultHint
            }
        }
    }

    @ViewBuilder
    private var workingCard: some View {
        if let level = cycle.workingKeyLevel {
            HStack(spacing: 12) {
                Text(level.type.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(level.type.tint.opacity(0.85)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("РАБОЧИЙ KEY LEVEL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Fmt.price(level.price))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 4)
                if let reference = cycle.referencePrice, reference > 0 {
                    Text(Fmt.distancePercent(level.price, from: reference))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.blue.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.blue.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var selectionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cycle.sortedKeyLevels) { level in
                    Chip(
                        title: Fmt.price(level.price),
                        isSelected: cycle.workingKeyLevel == level,
                        tint: level.type.tint
                    ) {
                        select(level)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var resultHint: some View {
        if cycle.aConditionsMet {
            InfoHint(
                text: "Point A сформирован. Нажмите «Далее», чтобы зафиксировать его цену.",
                tint: Theme.green,
                icon: "checkmark.circle"
            )
        } else {
            InfoHint(
                text: "A пока не сформирован: нужны все три условия. Если KL полностью поглощён — переходите к следующему уровню.",
                tint: Theme.orange,
                icon: "exclamationmark.triangle"
            )
        }
    }

    private func select(_ level: KeyLevel) {
        for item in cycle.keyLevels {
            item.isWorking = false
        }
        level.isWorking = true
        cycle.updatedAt = .now
        try? context.save()
        Haptics.select()
    }
}

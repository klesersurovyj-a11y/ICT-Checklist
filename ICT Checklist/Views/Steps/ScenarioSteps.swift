//
//  ScenarioSteps.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

// MARK: - Point A

struct PointAStep: View {
    @Bindable var cycle: TradingCycle

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let level = cycle.workingKeyLevel {
                HStack(spacing: 8) {
                    Text(level.type.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(level.type.tint.opacity(0.85)))
                    Text("KL \(Fmt.price(level.price))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
            }

            PriceField(title: "Цена Point A", placeholder: "0.0000", value: $cycle.pointAPrice)
            PriceField(title: "Глубина захода в A, %", placeholder: "Например 35", value: $cycle.pointADepth)

            ToggleRow(
                title: "A валиден (H4)",
                subtitle: "Пока A валиден — сценарий жив",
                isOn: $cycle.pointAValid
            )

            GlassNoteField(placeholder: "SNR, нарушенный OF, фрактал…", text: $cycle.pointANote, minHeight: 72)

            if cycle.scenarios.count > 1 {
                scenariosSection
            }

            if !cycle.pointAValid {
                endedCard(
                    title: "A потерял валидность — сценарий завершён",
                    text: "Новые входы по этому сценарию невозможны. Key Levels остаются активными: инвалидация сценария ≠ поглощение KL. Чтобы продолжить, сформируйте новый Point A."
                )
            } else if !cycle.pointBValid {
                endedCard(
                    title: "B потерял валидность — сценарий завершён",
                    text: "B не заменяется для спасения сценария: сначала должен сформироваться новый Point A, только потом новый B."
                )
            }

            InfoHint(text: "Текущий сценарий — наиболее актуальный Point A. Из нескольких валидных A/B выбирается один.")
        }
    }

    private var scenariosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СЦЕНАРИИ A/B")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            ForEach(cycle.sortedScenarios) { record in
                scenarioRow(record)
            }

            InfoHint(text: "Ориентир при выборе — глубина захода в A D1.")
        }
    }

    private func scenarioRow(_ record: ScenarioRecord) -> some View {
        Button {
            select(record)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A \(Fmt.price(record.pointAPrice))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(record.isSelectable ? .white : Theme.textSecondary)
                    Text(scenarioDetail(record))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if record.isCurrent {
                    tag("ТЕКУЩИЙ", tint: Theme.blue)
                } else if !record.isSelectable {
                    tag("НЕДЕЙСТВИТЕЛЕН", tint: Theme.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(record.isCurrent ? Theme.blue.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(record.isCurrent ? Theme.blue.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!record.isSelectable || record.isCurrent)
    }

    private func tag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    private func scenarioDetail(_ record: ScenarioRecord) -> String {
        let depth = Int(record.pointADepth.rounded())
        let b = record.pointBPrice.map { Fmt.price($0) } ?? "—"
        return "глубина \(depth)% · B \(b)"
    }

    private func select(_ record: ScenarioRecord) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cycle.pointAPrice = record.pointAPrice
            cycle.pointADepth = record.pointADepth
            cycle.pointAValid = record.pointAValid
            cycle.pointBPrice = record.pointBPrice
            cycle.pointBType = record.pointBType
            cycle.pointBValid = record.pointBValid
            for item in cycle.scenarios {
                item.isCurrent = false
            }
            record.isCurrent = true
        }
        try? context.save()
        Haptics.select()
    }

    private func endedCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.red)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Сформировать новый Point A") {
                startNewA()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.red.opacity(0.30), lineWidth: 1)
        )
    }

    private func startNewA() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            cycle.resetScenarioForNewPointA()
        }
        try? context.save()
        Haptics.tap()
    }
}

// MARK: - Point B

struct PointBStep: View {
    @Bindable var cycle: TradingCycle

    @Environment(\.modelContext) private var context

    private var ended: Bool { cycle.scenarioEnded }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if ended {
                endedCard
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PointBType.allCases) { type in
                        Chip(title: type.rawValue, isSelected: cycle.pointBType == type) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                cycle.pointBType = type
                            }
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .disabled(ended)
            .opacity(ended ? 0.45 : 1)

            PriceField(title: "Цена Point B", placeholder: "0.0000", value: $cycle.pointBPrice)
                .disabled(ended)
                .opacity(ended ? 0.45 : 1)

            if let level = cycle.sortedKeyLevels.first {
                Button {
                    cycle.pointBPrice = level.price
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                        Text("Ближайший уровень \(Fmt.price(level.price))")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(ended)
                .opacity(ended ? 0.45 : 1)
            }

            ToggleRow(
                title: "B валиден (H4)",
                subtitle: "Потеря B завершает сценарий",
                isOn: $cycle.pointBValid
            )

            GlassNoteField(
                placeholder: "Ближайший фрактал, FVG коррекции или граница диапазона…",
                text: $cycle.pointBNote,
                minHeight: 72
            )

            InfoHint(text: "B определяется сразу после A и не заменяется для спасения сценария.")
        }
    }

    private var endedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.red)
                Text(endedTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("B не заменяется для спасения сценария: сначала должен сформироваться новый Point A, только потом новый B. Цена и тип B заблокированы.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Сформировать новый Point A") {
                startNewA()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.red.opacity(0.30), lineWidth: 1)
        )
    }

    private var endedTitle: String {
        if !cycle.pointAValid && !cycle.pointBValid {
            return "A и B потеряли валидность — сценарий завершён"
        }
        return cycle.pointAValid
            ? "B потерял валидность — сценарий завершён"
            : "A потерял валидность — сценарий завершён"
    }

    private func startNewA() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            cycle.resetScenarioForNewPointA()
            cycle.step = .pointA
        }
        try? context.save()
        Haptics.tap()
    }
}

// MARK: - Confirmation

struct ConfirmationStep: View {
    @Bindable var cycle: TradingCycle
    let key: ConfirmationKey

    private var isConfirmed: Bool {
        cycle.confirmations.contains(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if cycle.scenarioEnded {
                InfoHint(
                    text: "Сценарий завершён: \(cycle.scenarioEndReason). Вернитесь к Point A — новые входы невозможны.",
                    tint: Theme.red,
                    icon: "xmark.octagon"
                )
            }

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    cycle.setConfirmation(key, !isConfirmed)
                }
                Haptics.tap()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isConfirmed ? Theme.blue : Color.white.opacity(0.07))
                            .frame(width: 46, height: 46)
                        Image(systemName: isConfirmed ? "checkmark" : "circle.dashed")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isConfirmed ? .white : Theme.textTertiary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(key.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(key.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isConfirmed ? Theme.blue.opacity(0.18) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isConfirmed ? Theme.blue.opacity(0.5) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(cycle.scenarioEnded)
            .opacity(cycle.scenarioEnded ? 0.5 : 1)

            HStack(spacing: 8) {
                ForEach(ConfirmationKey.allCases) { item in
                    Capsule()
                        .fill(cycle.confirmations.contains(item) ? Theme.blue : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }

            InfoHint(text: "Все пункты обязательны: отмечено \(cycle.confirmations.count) из 6.")
        }
    }
}

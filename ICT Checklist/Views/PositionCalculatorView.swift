//
//  PositionCalculatorView.swift
//  ICT Checklist
//
//  Калькулятор позиции: капитал, риск, уровни и объём до входа в сделку.
//

import SwiftUI
import SwiftData

struct PositionCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsList: [AppSettings]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var capital: Double? = nil
    @State private var riskPercent: Double = 1
    @State private var entry: Double? = nil
    @State private var stop: Double? = nil
    @State private var pipValue: Double = 10
    @State private var rr: Double = 2
    @State private var showNewTrade = false
    @State private var prefill: NewTradePrefill?
    @State private var didLoad = false

    private let riskOptions: [Double] = [0.5, 1, 2]
    private let rrOptions: [Double] = [1.5, 2, 3]

    // MARK: - Math

    private var capitalValue: Double { max(capital ?? 0, 0) }

    private var riskMoney: Double { capitalValue * riskPercent / 100 }

    private var distance: Double? {
        guard let entry, let stop, entry > 0, stop > 0 else { return nil }
        let value = abs(entry - stop)
        return value > 0 ? value : nil
    }

    private var direction: Direction {
        guard let entry, let stop else { return .long }
        return stop <= entry ? .long : .short
    }

    /// Шаг цены для «пунктов»: валюта, металл или индекс.
    private var pipSize: Double {
        let reference = entry ?? 0
        if reference >= 500 { return 0.1 }
        if reference >= 20 { return 0.01 }
        return 0.0001
    }

    private var pips: Double? {
        guard let distance else { return nil }
        return distance / pipSize
    }

    private var lots: Double? {
        guard let pips, pips > 0, pipValue > 0, riskMoney > 0 else { return nil }
        return riskMoney / (pips * pipValue)
    }

    private var takePrice: Double? {
        guard let entry, let distance else { return nil }
        let sign: Double = direction == .long ? 1 : -1
        return entry + sign * distance * rr
    }

    private var canCreate: Bool { lots != nil && takePrice != nil }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .reveal(.drop)
                    capitalCard
                        .reveal(.zoom, 1)
                    levelsCard
                        .reveal(.rise, 2)
                    resultCard
                        .reveal(.rise, 3)
                    createButton
                        .reveal(.rise, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .onAppear(perform: loadDefaults)
        .fullScreenCover(item: $prefill) { value in
            NewTradeView(prefill: value)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                ScreenTitle(text: "Калькулятор позиции")
                Text("Риск, объём и тейк до входа")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Capital

    private var capitalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Капитал и риск")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            numberRow("Сумма капитала", value: $capital, unit: "USD", placeholder: "10000")

            numberRow("Риск на сделку", value: riskPercentBinding, unit: "%", placeholder: "1")

            HStack(spacing: 8) {
                ForEach(riskOptions, id: \.self) { option in
                    Chip(
                        title: riskLabel(option),
                        isSelected: abs(riskPercent - option) < 0.001
                    ) {
                        riskPercent = option
                        Haptics.select()
                    }
                }
            }

            Divider()
                .overlay(Theme.hairline)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Риск в долларах")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Text(riskText)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Levels

    private var levelsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Уровни")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            numberRow("Цена входа", value: $entry, unit: nil, placeholder: "1.08420")
            numberRow("Стоп-лосс", value: $stop, unit: nil, placeholder: "1.08120")
            numberRow(
                "Стоимость пункта на лот",
                value: Binding(
                    get: { Optional(pipValue) },
                    set: { pipValue = max($0 ?? 0, 0) }
                ),
                unit: "USD",
                placeholder: "10"
            )

            Divider()
                .overlay(Theme.hairline)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Расстояние до стопа")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Text(pipsText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Result

    private var resultCard: some View {
        VStack(spacing: 10) {
            Text("Результат")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                Text("Объём позиции")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                Text(lotsText)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            HStack(spacing: 8) {
                ForEach(rrOptions, id: \.self) { option in
                    Chip(
                        title: "RR \(rrLabel(option))",
                        isSelected: abs(rr - option) < 0.001
                    ) {
                        rr = option
                        Haptics.select()
                    }
                }
            }

            Divider()
                .overlay(Theme.hairline)

            Text(takeText)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Button

    private var createButton: some View {
        Button {
            guard let entry, let stop, let takePrice else {
                Haptics.warning()
                return
            }
            prefill = NewTradePrefill(
                entry: entry,
                stop: stop,
                takeProfit: takePrice,
                riskUSD: riskMoney
            )
            Haptics.success()
        } label: {
            Text("Создать сделку")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.45)
        .padding(.top, 4)
    }

    // MARK: - Rows

    private func numberRow(
        _ title: String,
        value: Binding<Double?>,
        unit: String?,
        placeholder: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            CalcNumberField(value: value, unit: unit, placeholder: placeholder)
        }
    }

    // MARK: - Text

    private var riskPercentBinding: Binding<Double?> {
        Binding(
            get: { Optional(riskPercent) },
            set: { riskPercent = min(max($0 ?? 1, 0.1), 100) }
        )
    }

    private var riskText: String {
        String(format: "%.2f USD", riskMoney)
    }

    private var pipsText: String {
        guard let pips else { return "—" }
        let value = pips
        let rounded = (value * 10).rounded() / 10
        let text = rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
        return "\(text) \(pointsWord(rounded))"
    }

    private var lotsText: String {
        guard let lots else { return "—" }
        let text = String(format: "%.2f", lots)
        return "\(text) \(lotWord(lots))"
    }

    private var takeText: String {
        guard let takePrice else {
            return "Заполните вход и стоп"
        }
        return "Тейк при RR \(rrLabel(rr)) — \(Fmt.price(takePrice))"
    }

    private func riskLabel(_ value: Double) -> String {
        let text = value == value.rounded()
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(text) %"
    }

    private func rrLabel(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func pointsWord(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        let mod100 = abs(rounded) % 100
        let mod10 = abs(rounded) % 10
        if mod100 >= 11 && mod100 <= 14 { return "пунктов" }
        if mod10 == 1 { return "пункт" }
        if mod10 >= 2 && mod10 <= 4 { return "пункта" }
        return "пунктов"
    }

    private func lotWord(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded == 1 ? "лот" : "лота"
    }

    // MARK: - Defaults

    private func loadDefaults() {
        guard !didLoad else { return }
        didLoad = true

        let equity = accounts.first?.equity ?? 0
        capital = equity > 0 ? equity : 10_000
        pipValue = 10
        riskPercent = settingsList.first?.maxRiskPercent ?? 1
    }
}

// MARK: - Numeric field

private struct CalcNumberField: View {
    @Binding var value: Double?
    var unit: String?
    var placeholder: String = "0"

    @State private var text = ""

    private var width: CGFloat { unit == nil ? 140 : 150 }

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)

            if let unit {
                Text(unit)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .onAppear {
            text = format(value)
        }
        .onChange(of: text) { _, newValue in
            let normalized = newValue
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
            let parsed = Double(normalized)
            if parsed != value {
                value = parsed
            }
        }
        .onChange(of: value) { _, newValue in
            let normalized = text
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
            if Double(normalized) != newValue {
                text = newValue.map(format) ?? ""
            }
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "" }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return Fmt.price(value)
    }
}

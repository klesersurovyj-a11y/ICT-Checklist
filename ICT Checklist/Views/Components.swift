//
//  Components.swift
//  ICT Checklist
//

import SwiftUI

// MARK: - Buttons

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glassProminent)
            .tint(isEnabled ? Theme.accent : Theme.accent.opacity(0.35))
            .disabled(!isEnabled)
        } else {
            Button(action: action) {
                label
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isEnabled ? Theme.accent : Theme.accent.opacity(0.25))
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!isEnabled)
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(Theme.background)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassPanel(cornerRadius: 14)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Segmented control

struct GlassSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    var tint: (Option) -> Color = { _ in Theme.accent }

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(3)
        .glassPanel(cornerRadius: 13)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            guard !isSelected else { return }
            withAnimation(Theme.snappy) {
                selection = option
            }
            Haptics.select()
        } label: {
            Text(label(option))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint(option))
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var isSelected: Bool = false
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                label
                    .background(Capsule().fill(tint))
            } else {
                label
                    .glassCapsule()
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var label: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
    }
}

// MARK: - Fields

struct PriceField: View {
    let title: String
    var placeholder: String = "0.0000"
    @Binding var value: Double?

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .onAppear {
            text = value.map { Fmt.price($0) } ?? ""
        }
        .onChange(of: text) { _, newValue in
            let normalized = newValue.replacingOccurrences(of: ",", with: ".")
            let parsed = Double(normalized)
            if parsed != value {
                value = parsed
            }
        }
        .onChange(of: value) { _, newValue in
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            if Double(normalized) != newValue {
                text = newValue.map { Fmt.price($0) } ?? ""
            }
        }
    }
}

struct GlassNoteField: View {
    let placeholder: String
    @Binding var text: String
    var limit: Int = 500
    var lines: ClosedRange<Int> = 2...6
    var minHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(lines)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            Text("\(text.count)/\(limit)")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .padding(.trailing, 12)
                .padding(.bottom, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onChange(of: text) { _, newValue in
            if newValue.count > limit {
                text = String(newValue.prefix(limit))
            }
        }
    }
}

// MARK: - Rows

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .tint(.white)
        .padding(12)
        .glassPanel(cornerRadius: 14, interactive: true)
        .onChange(of: isOn) { _, _ in
            Haptics.select()
        }
    }
}

struct CheckRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOn.toggle()
            }
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOn ? Theme.accent : Color.white.opacity(0.06))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isOn ? Theme.background : Theme.textTertiary)
                }
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(isOn ? .white : Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.12) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hints

struct InfoHint: View {
    let text: String
    var tint: Color = Theme.textSecondary
    var icon: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
            Text(text)
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Metrics

struct MetricTile: View {
    let title: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .glassPanel(cornerRadius: 12)
    }
}

struct ZoneBar: View {
    let low: Double
    let high: Double
    let price: Double?

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let span = max(high - low, 0.0000001)
                let ratio = price.map { min(max(($0 - low) / span, 0), 1) } ?? 0

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.accent.opacity(0.16))
                        Rectangle().fill(Theme.orange.opacity(0.16))
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 1)
                        .offset(x: width / 2)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 26)
                        .offset(x: ratio * (width - 3))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 24)

            HStack {
                Text("Discount")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("Premium")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.orange)
            }
        }
    }
}

// MARK: - Summary

struct SummaryItem {
    let title: String
    let value: String
    var tint: Color = .white
}

struct SummaryTable: View {
    let items: [SummaryItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                        .overlay(Theme.hairline)
                }
                HStack {
                    Text(item.title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Text(item.value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(item.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 12)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Completed step row

struct CompletedStepRow: View {
    let step: CycleStep
    let summary: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(step.title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textPrimary)
                    Text(summary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Numeric row

struct NumberRow: View {
    let title: String
    var prefix: String = ""
    var suffix: String = ""
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100000
    var step: Double = 1
    var digits: Int = 0

    private var display: String {
        prefix + String(format: "%.\(digits)f", value) + suffix
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                button("minus") { adjust(-step) }
                Text(display)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .frame(minWidth: 62)
                button("plus") { adjust(step) }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func button(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 26, height: 26)
                .glassCircle()
        }
        .buttonStyle(.plain)
    }

    private func adjust(_ delta: Double) {
        let raw = value + delta
        let clamped = min(max(raw, range.lowerBound), range.upperBound)
        value = digits == 0 ? clamped.rounded() : (clamped * 10).rounded() / 10
        Haptics.select()
    }
}

// MARK: - Section tile

/// Плитка раздела: иконка, название, подпись и бейдж.
/// Используется в «Все разделы» и в сетке аналитики.
struct SectionTile: View {
    let title: String
    var subtitle: String = ""
    let icon: String
    var badge: String? = nil
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.14))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    Spacer(minLength: 4)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(tint))
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .glassCard(cornerRadius: 20, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Single line field

struct SingleLineField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

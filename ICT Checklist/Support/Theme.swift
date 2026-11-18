//
//  Theme.swift
//  ICT Checklist
//

import SwiftUI

enum Theme {
    static let accent = Color(hex: 0xFFFFFF)
    static let blue = accent
    static let lavender = Color(hex: 0xE4E4E4)
    static let teal = Color(hex: 0xBDBDBD)

    static let green = Color(hex: 0x7BE3B0)
    static let red = Color(hex: 0xFF8A8A)
    static let orange = Color(hex: 0xD6D6D6)

    static let background = Color(hex: 0x000000)
    static let backgroundImage = "AppBackground"
    static let surface = Color(hex: 0x0B0B0C)
    static let glassTint = Color.white.opacity(0.02)
    static let glassStroke = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.07)

    static let textPrimary = Color(hex: 0xF7F7F7)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.30)

    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let smooth = Animation.easeInOut(duration: 0.35)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension KeyLevelType {
    var tint: Color {
        switch self {
        case .snr: return Theme.accent
        case .fvg: return Theme.orange
        case .fractal: return Theme.green
        case .halfDR: return Theme.lavender
        }
    }
}

extension BrainKind {
    var tint: Color {
        switch self {
        case .observation: return Theme.textPrimary
        case .hypothesis: return Theme.lavender
        case .research: return Theme.teal
        case .rule: return Theme.accent
        case .pattern: return Theme.green
        case .keyNote: return Theme.lavender
        case .formula: return Theme.teal
        }
    }
}

extension BrainStatus {
    var tint: Color {
        switch self {
        case .idea: return Theme.textSecondary
        case .testing: return Theme.textPrimary
        case .confirmed: return Theme.green
        case .rejected: return Theme.red
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background

            GeometryReader { proxy in
                Image(Theme.backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.46),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var interactive: Bool = false

    private var radius: CGFloat { min(cornerRadius, 22) }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: .rect(cornerRadius: radius)
                )
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Theme.surface.opacity(0.45))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.015)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.9
                                )
                        }
                }
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    /// Нативная стеклянная поверхность для кнопок, сегментов и плиток.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    /// Стеклянная капсула — как у системных чипов iOS.
    @ViewBuilder
    func glassCapsule(interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .capsule
            )
        } else {
            self
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    /// Круглая стеклянная иконочная кнопка.
    @ViewBuilder
    func glassCircle(interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .circle
            )
        } else {
            self
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
    }
}

/// Мягкое появление блока при открытии экрана.
struct CardEntranceModifier: ViewModifier {
    var index: Int = 0

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(
                    .spring(response: 0.45, dampingFraction: 0.9)
                        .delay(Double(min(index, 8)) * 0.03)
                ) {
                    appeared = true
                }
            }
    }
}

extension View {
    func cardEntrance(_ index: Int = 0) -> some View {
        modifier(CardEntranceModifier(index: index))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(Theme.textTertiary)
    }
}

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .semibold))
            .tracking(-0.6)
            .foregroundStyle(Theme.textPrimary)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
    }
}

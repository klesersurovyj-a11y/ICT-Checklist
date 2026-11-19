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

/// Живой фон из прежней версии: та же фотография, медленно дышит.
struct AppBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var tilt = ParallaxTilt.shared
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background

            ZStack {
                GeometryReader { proxy in
                    Image(Theme.backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(reduceMotion ? 1 : 1.05 + phase * 0.07)
                        .offset(
                            x: reduceMotion ? 0 : (phase - 0.5) * 26,
                            y: reduceMotion ? 0 : (0.5 - phase) * 20
                        )
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 18).repeatForever(autoreverses: true),
                            value: phase
                        )
                }

                GeometryReader { proxy in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 420, height: 420)
                        .offset(x: -80 + phase * 120, y: -150 + phase * 90)
                        .blur(radius: 24)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 14).repeatForever(autoreverses: true),
                            value: phase
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.green.opacity(0.06), Theme.green.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .frame(width: 460, height: 460)
                        .offset(
                            x: proxy.size.width - 300 - phase * 70,
                            y: proxy.size.height * 0.48 + phase * 50
                        )
                        .blur(radius: 30)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 19).repeatForever(autoreverses: true),
                            value: phase
                        )
                }
            }
            .offset(
                x: reduceMotion ? 0 : CGFloat(tilt.offset.width) * 14,
                y: reduceMotion ? 0 : -CGFloat(tilt.offset.height) * 10
            )
            .animation(reduceMotion ? nil : .linear(duration: 0.2), value: tilt.offset)

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
        .onAppear {
            tilt.acquire()
            guard !reduceMotion else { return }
            phase = 1
        }
        .onDisappear {
            tilt.release()
        }
    }
}

/// Карточка из стекла, без обводки.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var interactive: Bool = false

    private var radius: CGFloat { min(cornerRadius, 22) }

    @ViewBuilder
    func body(content: Content) -> some View {
        Group {
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
                    }
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
            }
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

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

struct CardEntranceModifier: ViewModifier {
    var index: Int = 0

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(
                    .spring(response: 0.9, dampingFraction: 0.9)
                        .delay(Double(min(index, 8)) * 0.06)
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

/// Надзаголовок раздела — одна строка, без разбивки на буквы.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .pieceIn(delay: 0.2)
    }
}

/// Заголовок печатается медленно, без курсора.
struct ScreenTitle: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    var body: some View {
        Text(String(text.prefix(max(visibleCount, 0))))
            .font(.system(size: 26, weight: .semibold))
            .tracking(-0.6)
            .foregroundStyle(Theme.textPrimary)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) {
                if reduceMotion {
                    visibleCount = text.count
                    return
                }
                visibleCount = 0
                try? await Task.sleep(nanoseconds: 360_000_000)
                for index in 1...max(text.count, 1) {
                    try? await Task.sleep(nanoseconds: 62_000_000)
                    guard !Task.isCancelled else { return }
                    visibleCount = index
                }
            }
    }
}

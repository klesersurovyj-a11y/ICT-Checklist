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

struct AppBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background

            blobs
                .offset(x: drift * 70 - 35, y: drift * 50 - 25)
                .overlay(
                    blobs
                        .scaleEffect(1.18)
                        .offset(x: 40 - drift * 60, y: drift * 40 - 20)
                        .opacity(0.55)
                )
                .blur(radius: 62)

            // Стекло поверх фона: лёгкая дымка и затемнение по краям.
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.01), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.62)],
                center: .center,
                startRadius: 120,
                endRadius: 640
            )
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }

    private var blobs: some View {
        ZStack {
            blob(color: 0x3B5BFF, opacity: 0.60, size: 640)
                .offset(x: -130, y: -280)
            blob(color: 0x1FB6A8, opacity: 0.42, size: 520)
                .offset(x: 170, y: 110)
            blob(color: 0x7A3BFF, opacity: 0.34, size: 460)
                .offset(x: -50, y: 330)
            blob(color: 0xFF7A45, opacity: 0.20, size: 300)
                .offset(x: 150, y: -60)
        }
    }

    private func blob(color: UInt32, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: color).opacity(opacity), Color(hex: color).opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    private var radius: CGFloat { min(cornerRadius, 18) }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface.opacity(0.76))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.055), Color.white.opacity(0.012)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                    }
            }
            .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
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

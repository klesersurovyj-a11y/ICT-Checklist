//
//  Theme.swift
//  ICT Checklist
//

import SwiftUI

enum Theme {
    static let accent = Color(hex: 0x7C6BFF)
    static let blue = accent
    static let lavender = Color(hex: 0xB9AEFF)
    static let teal = Color(hex: 0x3FD6D0)

    static let green = Color(hex: 0x43D8A0)
    static let red = Color(hex: 0xFF6B6B)
    static let orange = Color(hex: 0xFFB65C)

    static let background = Color(hex: 0x07080C)
    static let surface = Color(hex: 0x0E1016)
    static let glassTint = Color.black.opacity(0.22)
    static let glassStroke = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.05)

    static let textPrimary = Color(hex: 0xF2F3F7)
    static let textSecondary = Color.white.opacity(0.50)
    static let textTertiary = Color.white.opacity(0.28)
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
    var body: some View {
        ZStack {
            Theme.background

            RadialGradient(
                colors: [Theme.accent.opacity(0.30), Theme.accent.opacity(0.06), .clear],
                center: UnitPoint(x: 0.12, y: -0.18),
                startRadius: 20,
                endRadius: 640
            )

            RadialGradient(
                colors: [Theme.teal.opacity(0.10), .clear],
                center: UnitPoint(x: 1.05, y: 0.98),
                startRadius: 20,
                endRadius: 520
            )

            LinearGradient(
                colors: [Color.white.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.32)
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.glassTint)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.glassStroke, lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.textTertiary)
    }
}

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .semibold))
            .tracking(-0.4)
            .foregroundStyle(Theme.textPrimary)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}

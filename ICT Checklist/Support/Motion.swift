//
//  Motion.swift
//  ICT Checklist
//
//  Анимации появления: блоки «прилетают» на свои места.
//

import SwiftUI

/// Разные способы, которыми блоки появляются на экране,
/// чтобы страницы не выглядели одинаково.
enum RevealStyle {
    case rise
    case drop
    case slideLeft
    case slideRight
    case zoom
    case blur
    case tilt
    case unfurl

    struct Config {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var anchor: UnitPoint = .center
        var rotation: Double = 0
        var blur: CGFloat = 0
        var spring: Double = 0.55
        var damping: Double = 0.84
        var stagger: Double = 0.055
    }

    var config: Config {
        switch self {
        case .rise:
            return Config(dy: 30, scaleX: 0.97, scaleY: 0.97)
        case .drop:
            return Config(dy: -30, scaleX: 0.98, scaleY: 0.98, damping: 0.8)
        case .slideLeft:
            return Config(dx: -46, scaleX: 0.99, scaleY: 0.99, spring: 0.6)
        case .slideRight:
            return Config(dx: 46, scaleX: 0.99, scaleY: 0.99, spring: 0.6)
        case .zoom:
            return Config(dy: 8, scaleX: 0.86, scaleY: 0.86, damping: 0.76)
        case .blur:
            return Config(dy: 16, blur: 10, damping: 0.9)
        case .tilt:
            return Config(dy: 34, scaleX: 0.94, scaleY: 0.94, rotation: -14, damping: 0.78)
        case .unfurl:
            return Config(scaleY: 0.12, anchor: .top, spring: 0.62, damping: 0.86, stagger: 0.04)
        }
    }
}

private struct RevealTickKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// Меняется при каждом переходе на раздел — блоки собираются заново.
    var revealTick: Int {
        get { self[RevealTickKey.self] }
        set { self[RevealTickKey.self] = newValue }
    }
}

struct RevealModifier: ViewModifier {
    let style: RevealStyle
    let index: Int
    let extraDelay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.revealTick) private var revealTick
    @State private var shown = false

    func body(content: Content) -> some View {
        let config = style.config

        return content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : config.dx, y: shown ? 0 : config.dy)
            .scaleEffect(
                x: shown ? 1 : config.scaleX,
                y: shown ? 1 : config.scaleY,
                anchor: config.anchor
            )
            .rotation3DEffect(
                .degrees(shown ? 0 : config.rotation),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .blur(radius: shown ? 0 : config.blur)
            .animation(
                .spring(response: config.spring, dampingFraction: config.damping)
                    .delay(extraDelay + Double(min(index, 12)) * config.stagger),
                value: shown
            )
            .onChange(of: revealTick) { _, _ in
                replay()
            }
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
                shown = true
            }
    }

    private func replay() {
        guard !reduceMotion else {
            shown = true
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shown = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 24_000_000)
            shown = true
        }
    }
}

extension View {
    /// Появление блока на экране. Стиль и порядок задают рисунок страницы.
    func reveal(_ style: RevealStyle = .rise, _ index: Int = 0, delay: Double = 0) -> some View {
        modifier(RevealModifier(style: style, index: index, extraDelay: delay))
    }
}

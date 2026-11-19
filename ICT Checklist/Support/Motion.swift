//
//  Motion.swift
//  ICT Checklist
//
//  Сборка экранов из деталей: падения, толчки, облёты, запуск приборов.
//

import SwiftUI

enum RevealStyle {
    /// Падает сверху и «приземляется» с отскоком и ударной волной.
    case drop
    /// Влетает сбоку и с толчком встаёт на место.
    case slideLeft
    case slideRight
    /// Влетает откуда-то извне по дуге.
    case rise
    /// Собирается из глубины поворотом.
    case zoom
    /// Наносится ветром — целиком, с размытием.
    case blur
    /// Кувыркается в 3D и падает на место.
    case tilt
    /// Раскрывается сверху вниз.
    case unfurl

    struct Config {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var anchor: UnitPoint = .center
        var rotationX: Double = 0
        var rotationY: Double = 0
        var rotationZ: Double = 0
        var perspective: CGFloat = 0.7
        var blur: CGFloat = 0
        var spring: Double = 0.85
        var damping: Double = 0.6
        var stagger: Double = 0.11
        /// Оставляет ли блок ударную волну в точке посадки.
        var impact: Bool = false
    }

    /// С какой точки каталога движений начинается экран.
    var offset: Int {
        switch self {
        case .drop: return 0
        case .slideLeft: return 1
        case .rise: return 2
        case .zoom: return 3
        case .blur: return 4
        case .tilt: return 5
        case .unfurl: return 6
        case .slideRight: return 10
        }
    }

    /// Шестнадцать разных появлений: у каждого блока своё.
    static let catalogue: [Config] = [
        // 0 — опускается сверху и мягко садится
        Config(dy: -180, scaleX: 0.97, scaleY: 0.99, anchor: .bottom, rotationX: 8, blur: 6, spring: 0.95, damping: 0.88, stagger: 0.09, impact: true),
        // 1 — подплывает слева
        Config(dx: -160, scaleX: 0.96, scaleY: 0.97, anchor: .trailing, rotationY: 12, blur: 6, spring: 0.9, damping: 0.9, stagger: 0.08),
        // 2 — идёт по пологой дуге с нижнего правого угла
        Config(dx: 110, dy: 150, scaleX: 0.94, scaleY: 0.94, rotationX: -12, rotationY: 10, blur: 8, spring: 0.95, damping: 0.9, stagger: 0.08),
        // 3 — проявляется из глубины
        Config(scaleX: 0.9, scaleY: 0.9, rotationX: -10, blur: 10, spring: 1, damping: 0.92, stagger: 0.07),
        // 4 — наносит ветром
        Config(dx: -50, dy: 10, scaleX: 1.02, scaleY: 0.97, rotationZ: -1.5, blur: 12, spring: 1.05, damping: 0.92, stagger: 0.07),
        // 5 — поворачивается на место
        Config(dy: 120, scaleX: 0.93, scaleY: 0.93, rotationX: -20, rotationY: 10, blur: 7, spring: 0.95, damping: 0.9, stagger: 0.08),
        // 6 — раскрывается сверху вниз
        Config(scaleY: 0.55, anchor: .top, rotationX: -10, blur: 6, spring: 0.95, damping: 0.9, stagger: 0.08),
        // 7 — поднимается снизу
        Config(dy: 160, scaleX: 0.94, scaleY: 0.94, rotationZ: 1.5, blur: 8, spring: 0.9, damping: 0.9, stagger: 0.07),
        // 8 — разворачивается со стороны
        Config(scaleX: 0.97, scaleY: 0.97, anchor: .leading, rotationY: 26, perspective: 0.8, blur: 4, spring: 0.95, damping: 0.92, stagger: 0.08),
        // 9 — разворачивается сверху
        Config(dy: -40, scaleX: 0.97, scaleY: 0.97, anchor: .top, rotationX: 24, perspective: 0.8, blur: 4, spring: 0.95, damping: 0.92, stagger: 0.08),
        // 10 — подплывает справа
        Config(dx: 160, scaleX: 0.96, scaleY: 0.97, anchor: .leading, rotationY: -12, blur: 6, spring: 0.9, damping: 0.9, stagger: 0.08),
        // 11 — опускается сверху с лёгким наклоном
        Config(dy: -110, scaleX: 0.96, scaleY: 0.96, rotationX: 12, rotationZ: -2, blur: 5, spring: 0.92, damping: 0.9, stagger: 0.09),
        // 12 — медленно подплывает
        Config(dx: 60, dy: 36, scaleX: 0.97, scaleY: 0.97, rotationZ: 2, blur: 8, spring: 1.15, damping: 0.95, stagger: 0.1),
        // 13 — подплывает по дуге с левого низа
        Config(dx: -130, dy: 60, anchor: .trailing, rotationZ: -6, blur: 6, spring: 1, damping: 0.9, stagger: 0.08),
        // 14 — спокойно выезжает вверх
        Config(dy: 60, scaleX: 0.98, scaleY: 0.98, blur: 2, spring: 1.05, damping: 0.95, stagger: 0.08),
        // 15 — проявляется, слегка уменьшаясь
        Config(scaleX: 1.04, scaleY: 1.04, blur: 10, spring: 1, damping: 0.94, stagger: 0.07)
    ]

    /// Заголовки появляются спокойно, без кувырков.
    static let headerPicks = [0, 4, 12, 14]

    /// Движение для блока: свой у каждого индекса и свой у каждого экрана.
    func move(for index: Int, seed: Int) -> Config {
        if index == 0 {
            let pick = RevealStyle.headerPicks[(seed + offset) % RevealStyle.headerPicks.count]
            return RevealStyle.catalogue[pick]
        }
        let count = RevealStyle.catalogue.count
        return RevealStyle.catalogue[(offset * 3 + index * 5 + seed) % count]
    }
}

private struct RevealTickKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
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
    @State private var impact: CGFloat = 0
    @State private var seed = Int.random(in: 0..<16)

    func body(content: Content) -> some View {
        let move = style.move(for: index, seed: seed)

        return content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : move.dx, y: shown ? 0 : move.dy)
            .scaleEffect(
                x: shown ? 1 : move.scaleX,
                y: shown ? 1 : move.scaleY,
                anchor: move.anchor
            )
            .rotation3DEffect(
                .degrees(shown ? 0 : move.rotationX),
                axis: (x: 1, y: 0, z: 0),
                perspective: move.perspective
            )
            .rotation3DEffect(
                .degrees(shown ? 0 : move.rotationY),
                axis: (x: 0, y: 1, z: 0),
                perspective: move.perspective
            )
            .rotationEffect(.degrees(shown ? 0 : move.rotationZ))
            .blur(radius: shown ? 0 : move.blur)
            .overlay(alignment: .bottom) {
                if move.impact {
                    Ellipse()
                        .stroke(Color.white.opacity(0.22 * (1 - impact)), lineWidth: 1.5)
                        .frame(width: 60 + impact * 140, height: 10 + impact * 16)
                        .offset(y: 6)
                        .allowsHitTesting(false)
                }
            }
            .animation(
                .spring(response: move.spring, dampingFraction: move.damping)
                    .delay(extraDelay + Double(min(index, 16)) * move.stagger),
                value: shown
            )
            .animation(.easeOut(duration: 0.7), value: impact)
            .onChange(of: revealTick) { _, _ in
                replay(move)
            }
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
                shown = true
                if move.impact {
                    try? await Task.sleep(nanoseconds: 520_000_000)
                    impact = 1
                }
            }
    }

    private func replay(_ move: RevealStyle.Config) {
        guard !reduceMotion else {
            shown = true
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shown = false
            impact = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 24_000_000)
            shown = true
            if move.impact {
                try? await Task.sleep(nanoseconds: 520_000_000)
                impact = 1
            }
        }
    }
}

struct IconPopModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var jitter = Double.random(in: 0..<1)

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.74 + jitter * 0.1)
            .rotation3DEffect(
                .degrees(shown ? 0 : 40 + jitter * 44),
                axis: (x: jitter * 0.4, y: 1, z: 0),
                perspective: 0.6
            )
            .opacity(shown ? 1 : 0)
            .animation(
                .spring(response: 0.85 + jitter * 0.15, dampingFraction: 0.88).delay(delay),
                value: shown
            )
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
                shown = true
            }
    }
}

/// Деталь влетает со своего направления и мягко встаёт на место.
struct PieceInModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var jitter = Double.random(in: 0..<1)

    func body(content: Content) -> some View {
        let phase = (jitter + abs(delay * 137)).truncatingRemainder(dividingBy: 1)
        let driftX = (phase - 0.5) * 56
        let driftY = 14 + phase * 26
        let angle = -6 - phase * 12

        return content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : driftX, y: shown ? 0 : -driftY)
            .scaleEffect(shown ? 1 : 0.94 + phase * 0.03)
            .rotation3DEffect(
                .degrees(shown ? 0 : angle),
                axis: (x: 1, y: 0.3 + phase * 0.5, z: 0),
                perspective: 0.6
            )
            .blur(radius: shown ? 0 : 1 + phase * 3)
            .animation(
                .spring(response: 0.8 + phase * 0.15, dampingFraction: 0.88).delay(delay),
                value: shown
            )
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 60_000_000)
                shown = true
            }
    }
}

/// Текст наносит ветром целиком.
struct WindInModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var fromLeft = Bool.random()

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(
                x: shown ? 0 : (fromLeft ? -30 : 30),
                y: shown ? 0 : (fromLeft ? 6 : -4)
            )
            .blur(radius: shown ? 0 : 6)
            .animation(
                .spring(response: 1.0, dampingFraction: 0.92).delay(delay),
                value: shown
            )
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 60_000_000)
                shown = true
            }
    }
}

/// Кнопки влетают броском: по дуге, с лёгким вращением и мягкой посадкой.
struct ButtonAssemblyModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var fromLeft = Bool.random()

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : (fromLeft ? -46 : 46), y: shown ? 0 : -70)
            .scaleEffect(shown ? 1 : 0.84)
            .rotationEffect(.degrees(shown ? 0 : (fromLeft ? -55 : 55)))
            .animation(
                .spring(response: 0.85, dampingFraction: 0.86).delay(delay),
                value: shown
            )
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 60_000_000)
                shown = true
            }
    }
}

struct BarGrowModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: shown ? 1 : 0.06, anchor: .bottom)
            .opacity(shown ? 1 : 0.3)
            .animation(
                .spring(response: 0.85, dampingFraction: 0.9).delay(delay),
                value: shown
            )
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
                shown = true
            }
    }
}

/// Прибор включается: график прорисовывается слева направо, по нему бежит луч.
struct ChartSweepModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1
    @State private var animated = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    if animated && progress < 0.999 {
                        LinearGradient(
                            colors: [Color.clear, Theme.accent.opacity(0.55), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 3, height: proxy.size.height)
                        .offset(x: proxy.size.width * progress)
                        .blur(radius: 1)
                        .allowsHitTesting(false)
                    }
                }
            }
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: proxy.size.width * progress)
                }
            }
            .task {
                guard !animated else { return }
                animated = true
                if reduceMotion {
                    progress = 1
                    return
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    progress = 0
                }
                try? await Task.sleep(nanoseconds: UInt64(max(delay, 0) * 1_000_000_000))
                withAnimation(.easeInOut(duration: 1.6)) {
                    progress = 1
                }
            }
    }
}

extension View {
    func reveal(_ style: RevealStyle = .rise, _ index: Int = 0, delay: Double = 0) -> some View {
        modifier(RevealModifier(style: style, index: index, extraDelay: delay))
    }

    func iconPop(delay: Double = 0) -> some View {
        modifier(IconPopModifier(delay: delay))
    }

    func pieceIn(delay: Double) -> some View {
        modifier(PieceInModifier(delay: delay))
    }

    /// Текст, который вносит ветром целиком.
    func windIn(delay: Double = 0.1) -> some View {
        modifier(WindInModifier(delay: delay))
    }

    /// Кнопка влетает как брошенный мяч.
    func buttonAssembly(delay: Double = 0.1) -> some View {
        modifier(ButtonAssemblyModifier(delay: delay))
    }

    /// Столбик вырастает снизу.
    func barGrow(delay: Double = 0) -> some View {
        modifier(BarGrowModifier(delay: delay))
    }

    /// График запускается как приборная панель.
    func chartSweep(delay: Double = 0.2) -> some View {
        modifier(ChartSweepModifier(delay: delay))
    }
}

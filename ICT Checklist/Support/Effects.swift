//
//  Effects.swift
//  ICT Checklist
//
//  Живые числа, блики на стекле, скелетоны, появление итога и параллакс фона.
//

import SwiftUI
import CoreMotion

// MARK: - Живые числа

/// Число, которое перекатывается от прежнего значения к новому
/// и коротко подсвечивается, когда меняется.
struct NumericText: View {
    let text: String
    var font: Font = .system(size: 15, weight: .semibold, design: .rounded)
    var tint: Color = Theme.textPrimary
    var glow: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.45), value: text)
            .shadow(color: tint.opacity(glow && flash ? 0.5 : 0), radius: flash ? 6 : 0)
            .onChange(of: text) { _, _ in
                guard glow, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    flash = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    withAnimation(.easeOut(duration: 0.7)) {
                        flash = false
                    }
                }
            }
    }
}

// MARK: - Блик по стеклу

/// Один медленный блик, проходящий по стеклянной карточке после её появления.
struct SpecularSweepModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var delay: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.16), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 2)
                        .rotationEffect(.degrees(22))
                        .offset(x: proxy.size.width * phase, y: -proxy.size.height * 0.5)
                        .blendMode(.plusLighter)
                    }
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.5).delay(delay)) {
                    phase = 1.6
                }
            }
    }
}

// MARK: - Скелетоны загрузки

struct ShimmerModifier: ViewModifier {
    var cornerRadius: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.02),
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(proxy.size.width * 0.7, 1))
                        .offset(x: proxy.size.width * phase)
                    }
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

/// Прямоугольник-заглушка с бегущим бликом.
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .modifier(ShimmerModifier(cornerRadius: height / 2))
    }
}

// MARK: - Появление итога

/// Итог «впечатывается»: приходит сверху крупнее и оставляет короткий ореол.
struct VerdictStampModifier: ViewModifier {
    var delay: Double = 0.15

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var glow = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 1.22)
            .opacity(shown ? 1 : 0)
            .shadow(color: Color.white.opacity(glow ? 0.35 : 0), radius: glow ? 10 : 0)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.55, dampingFraction: 0.72).delay(delay),
                value: shown
            )
            .animation(.easeOut(duration: 0.6), value: glow)
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                try? await Task.sleep(nanoseconds: 60_000_000)
                shown = true
                glow = true
                try? await Task.sleep(nanoseconds: 420_000_000)
                glow = false
            }
    }
}

// MARK: - Вход вкладки

/// Вкладка входит мягко: сжимается на сотую и проявляется.
struct TabEntranceModifier: ViewModifier {
    @Environment(\.revealTick) private var revealTick
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = true

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0.55)
            .scaleEffect(shown ? 1 : 0.985)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: shown)
            .onChange(of: revealTick) { _, _ in
                guard !reduceMotion else { return }
                shown = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    shown = true
                }
            }
    }
}

// MARK: - Полоса цикла

/// Тонкая полоса цикла дня: сколько уже прошло и сколько осталось.
struct CycleProgressStrip: View {
    var startHour: Int = 19
    var startMinute: Int = 0
    var endHour: Int = 22
    var endMinute: Int = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let window = Self.window(
                for: context.date,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute
            )
            CycleProgressBar(
                progress: Self.progress(for: context.date, window: window),
                caption: Self.caption(for: context.date, window: window)
            )
        }
    }

    static func window(
        for date: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.second = 0
        comps.hour = startHour
        comps.minute = startMinute
        guard var start = calendar.date(from: comps) else { return nil }
        comps.hour = endHour
        comps.minute = endMinute
        guard var end = calendar.date(from: comps) else { return nil }
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        if date < start,
           let prevStart = calendar.date(byAdding: .day, value: -1, to: start),
           let prevEnd = calendar.date(byAdding: .day, value: -1, to: end),
           date < prevEnd {
            start = prevStart
            end = prevEnd
        }
        return (start, end)
    }

    static func progress(for date: Date, window: (start: Date, end: Date)?) -> Double {
        guard let window else { return 0 }
        let total = window.end.timeIntervalSince(window.start)
        guard total > 1 else { return 0 }
        return min(max(date.timeIntervalSince(window.start) / total, 0), 1)
    }

    static func caption(for date: Date, window: (start: Date, end: Date)?) -> String {
        guard let window else { return "" }
        if date < window.start {
            let minutes = max(Int(window.start.timeIntervalSince(date) / 60), 1)
            return "до старта \(duration(minutes))"
        }
        if date >= window.end {
            return "цикл закрыт"
        }
        let minutes = max(Int(window.end.timeIntervalSince(date) / 60), 1)
        return "до закрытия \(duration(minutes))"
    }

    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)м" }
        if rest == 0 { return "\(hours)ч" }
        return "\(hours)ч \(rest)м"
    }
}

private struct CycleProgressBar: View {
    let progress: Double
    let caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("ЦИКЛ ДНЯ")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 4)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.green.opacity(0.55), Theme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, proxy.size.width * shownProgress))
                        .shadow(color: Theme.accent.opacity(0.35), radius: 5, x: 0, y: 0)
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            let target = CGFloat(min(max(progress, 0), 1))
            if reduceMotion {
                shownProgress = target
            } else {
                withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
                    shownProgress = target
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            let target = CGFloat(min(max(newValue, 0), 1))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
                shownProgress = target
            }
        }
    }
}

// MARK: - Параллакс фона

/// Наклон устройства слегка сдвигает фон и световые пятна.
@MainActor
final class ParallaxTilt: ObservableObject {
    static let shared = ParallaxTilt()

    /// Смещение по осям в диапазоне −1...1.
    @Published private(set) var offset: CGSize = .zero

    private let manager = CMMotionManager()
    private var users = 0

    private init() {}

    func acquire() {
        users += 1
        guard users == 1 else { return }
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 10.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = max(-1, min(1, motion.attitude.roll))
            let pitch = max(-1, min(1, motion.attitude.pitch))
            Task { @MainActor in
                guard let self else { return }
                if abs(self.offset.width - roll) < 0.01,
                   abs(self.offset.height - pitch) < 0.01 {
                    return
                }
                self.offset = CGSize(width: roll, height: pitch)
            }
        }
    }

    func release() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        offset = .zero
    }
}

// MARK: - Расширения

extension View {
    /// Один блик по стеклянной поверхности после появления.
    func specularSweep(cornerRadius: CGFloat = 20, delay: Double = 0.55) -> some View {
        modifier(SpecularSweepModifier(cornerRadius: cornerRadius, delay: delay))
    }

    /// Итог впечатывается на место.
    func verdictStamp(delay: Double = 0.15) -> some View {
        modifier(VerdictStampModifier(delay: delay))
    }

    /// Мягкий вход содержимого вкладки.
    func tabEntrance() -> some View {
        modifier(TabEntranceModifier())
    }
}


// MARK: - Пустое состояние

/// Линейный знак, который медленно дышит, — для экранов, где пока нечего показать.
struct BreathingGlyph: View {
    var systemName: String
    var tint: Color = Theme.textSecondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.16), Color.clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 60
                    )
                )
                .frame(width: 96, height: 96)
                .scaleEffect(reduceMotion ? 1 : 0.94 + phase * 0.12)

            Image(systemName: systemName)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(tint.opacity(0.85))
        }
        .frame(width: 96, height: 96)
        .animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: phase)
        .onAppear {
            guard !reduceMotion else { return }
            phase = 1
        }
    }
}

// MARK: - Обновление

/// Тонкое кольцо вместо системного индикатора во время обновления.
struct RefreshRing: View {
    var tint: Color = Theme.accent

    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 18, height: 18)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
            .onAppear {
                spin = true
            }
    }
}


// MARK: - Заставка при запуске

/// Короткая заставка: кольцо обрисовывается вокруг знака, затем уходит.
struct LaunchMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: 96, height: 96)

                    Circle()
                        .trim(from: 0, to: shown ? 1 : 0)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                        .animation(reduceMotion ? nil : .easeOut(duration: 1.0), value: shown)

                    Text("ICT")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textPrimary)
                }

                Text("ЦИКЛ · СДЕЛКИ · СТАТИСТИКА")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .scaleEffect(shown ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: shown)
        }
        .ignoresSafeArea()
        .task {
            shown = true
        }
    }
}


// MARK: - Подсветка совпадений

/// Текст, в котором совпадения с запросом выделены акцентом и жирным.
struct HighlightedText: View {
    let text: String
    let query: String

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return result }

        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                of: needle,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex
              ) {
            if let lower = AttributedString.Index(range.lowerBound, within: result),
               let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
                result[lower..<upper].foregroundColor = Theme.accent
            }
            searchStart = range.upperBound
        }
        return result
    }
}

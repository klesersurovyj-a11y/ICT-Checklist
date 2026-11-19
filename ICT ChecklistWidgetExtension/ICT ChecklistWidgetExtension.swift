//
//  ICT ChecklistWidgetExtension.swift
//  ICT Checklist
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Shared snapshot

enum WidgetData {
    static let appGroup = "group.com.organizationName.ICT-Checklist.shared"
    static let key = "ladderSnapshot"

    struct WeekDay: Codable {
        var label: String
        var r: Double
    }

    struct Payload: Codable {
        var stepIndex: Int
        var amount: Double
        var accumulatedR: Double
        var lastR: Double?
        var updatedAt: Date
        var weekR: Double?
        var weekTrades: Int?
        var weekWins: Int?
        var weekDays: [WeekDay]?

        // Цикл дня: поля необязательные, чтобы старые данные читались без ошибок.
        var cycleStart: Date?
        var cycleEnd: Date?
        var cycleTrades: Int?
        var cycleMaxTrades: Int?
        var cycleR: Double?
        var cycleMaxR: Double?
        var cycleLimits: Bool?
        var openSymbol: String?
        var openDirection: String?
        var openIsBE: Bool?
        var openTargetR: Double?
        var openStopR: Double?
    }

    static func load() -> Payload? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}

// MARK: - Entry

struct NextTradeEntry: TimelineEntry {
    let date: Date
    let stepIndex: Int
    let amount: Double
    let accumulatedR: Double
    let lastR: Double?

    static var empty: NextTradeEntry {
        NextTradeEntry(date: .now, stepIndex: 0, amount: 12, accumulatedR: 0, lastR: nil)
    }
}

// MARK: - Provider

struct NextTradeProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTradeEntry {
        NextTradeEntry(date: .now, stepIndex: 1, amount: 25, accumulatedR: 1.2, lastR: 2.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTradeEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTradeEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }

    private func loadEntry() -> NextTradeEntry {
        guard let payload = WidgetData.load() else { return .empty }
        return NextTradeEntry(
            date: payload.updatedAt,
            stepIndex: payload.stepIndex,
            amount: payload.amount,
            accumulatedR: payload.accumulatedR,
            lastR: payload.lastR
        )
    }
}

// MARK: - View

struct NextTradeEntryView: View {
    var entry: NextTradeEntry

    @Environment(\.widgetFamily) private var family

    private var accumuletedColor: Color {
        entry.accumulatedR >= 0 ? .green : .red
    }

    var body: some View {
        Group {
            if family == .systemLarge {
                largeBody
            } else {
                smallBody
            }
        }
        .widgetContainerBackground()
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("СЛЕДУЮЩАЯ СДЕЛКА")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(money(entry.amount))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("Ступень \(entry.stepIndex + 1) из 3")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(rText(entry.accumulatedR))
                    .foregroundStyle(accumuletedColor)
                Spacer(minLength: 0)
                if let lastR = entry.lastR {
                    Text("последний \(rText(lastR))")
                        .foregroundStyle(rColor(lastR))
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("СЛЕДУЮЩАЯ СДЕЛКА")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("Ступень \(entry.stepIndex + 1) из 3")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(money(entry.amount))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.45)

            Text("риск на сделку по Risk Ladder")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            stepRail

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                WidgetStatCell(
                    title: "Накоплено",
                    value: rText(entry.accumulatedR),
                    tint: accumuletedColor
                )

                if let lastR = entry.lastR {
                    WidgetStatCell(
                        title: "Последняя",
                        value: rText(lastR),
                        tint: rColor(lastR)
                    )
                } else {
                    WidgetStatCell(title: "Последняя", value: "—", tint: .secondary)
                }
            }
        }
    }

    private var stepRail: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= entry.stepIndex ? Color.accentColor : Color.white.opacity(0.12))
                    .frame(height: 6)
            }
        }
    }

    private func money(_ value: Double) -> String {
        let digits = value == value.rounded() ? 0 : 2
        return "$" + String(format: "%.\(digits)f", value)
    }

    private func rText(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0R" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f", abs(value)) + "R"
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return .green }
        if value < -0.05 { return .red }
        return .secondary
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.04, blue: 0.06)
            }
        } else {
            self.background(Color(red: 0.03, green: 0.04, blue: 0.06))
        }
    }
}

// MARK: - Large widget pieces

/// Небольшая плитка «подпись + значение» для крупных виджетов.
struct WidgetStatCell: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Week entry

struct WeekStatsEntry: TimelineEntry {
    let date: Date
    let weekR: Double
    let trades: Int
    let wins: Int
    let days: [WidgetData.WeekDay]

    static var empty: WeekStatsEntry {
        WeekStatsEntry(date: .now, weekR: 0, trades: 0, wins: 0, days: [])
    }
}

// MARK: - Week provider

struct WeekStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekStatsEntry {
        WeekStatsEntry(
            date: .now,
            weekR: 8.4,
            trades: 12,
            wins: 7,
            days: [
                WidgetData.WeekDay(label: "ПН", r: 2.0),
                WidgetData.WeekDay(label: "ВТ", r: -1.0),
                WidgetData.WeekDay(label: "СР", r: 3.0),
                WidgetData.WeekDay(label: "ЧТ", r: 0),
                WidgetData.WeekDay(label: "ПТ", r: 4.4),
                WidgetData.WeekDay(label: "СБ", r: 0),
                WidgetData.WeekDay(label: "ВС", r: 0)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekStatsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekStatsEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }

    private func loadEntry() -> WeekStatsEntry {
        guard let payload = WidgetData.load() else { return .empty }
        return WeekStatsEntry(
            date: payload.updatedAt,
            weekR: payload.weekR ?? 0,
            trades: payload.weekTrades ?? 0,
            wins: payload.weekWins ?? 0,
            days: payload.weekDays ?? []
        )
    }
}

// MARK: - Week view

struct WeekStatsEntryView: View {
    let entry: WeekStatsEntry

    @Environment(\.widgetFamily) private var family

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        case .systemLarge:
            largeBody.widgetContainerBackground()
        case .systemMedium:
            mediumBody.widgetContainerBackground()
        default:
            smallBody.widgetContainerBackground()
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("НЕДЕЛЯ")
                .font(.system(size: 10, weight: .semibold))
                .widgetAccentable()

            Text(rText(entry.weekR))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()

            WeekBars(days: entry.days, showLabels: false)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryInline: some View {
        Text("\(rText(entry.weekR)) · \(winPercent)% · \(dealsText(entry.trades))")
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ИТОГИ НЕДЕЛИ")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(rText(entry.weekR))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(entry.weekR))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(summaryLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            WeekBars(days: entry.days, showLabels: false)
                .frame(height: 22)
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ИТОГИ НЕДЕЛИ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(rText(entry.weekR))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rColor(entry.weekR))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("за 7 дней")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(summaryLine)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            WeekBars(days: entry.days, showLabels: true)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
        }
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("ИТОГИ НЕДЕЛИ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("7 дней")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(rText(entry.weekR))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rColor(entry.weekR))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(summaryLine)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

            WeekBars(days: entry.days, showLabels: true, barArea: 104)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                WidgetStatCell(title: "Лучший день", value: bestDayText, tint: .green)
                WidgetStatCell(title: "Худший день", value: worstDayText, tint: .red)
            }
        }
    }

    private var bestDayText: String {
        guard let day = entry.days.max(by: { $0.r < $1.r }), abs(day.r) >= 0.05 else {
            return "—"
        }
        return "\(day.label) \(rText(day.r))"
    }

    private var worstDayText: String {
        guard let day = entry.days.min(by: { $0.r < $1.r }), abs(day.r) >= 0.05 else {
            return "—"
        }
        return "\(day.label) \(rText(day.r))"
    }

    private var summaryLine: String {
        "\(winPercent)% win rate · \(dealsText(entry.trades))"
    }

    private var winPercent: Int {
        guard entry.trades > 0 else { return 0 }
        return Int((Double(entry.wins) / Double(entry.trades) * 100).rounded())
    }

    private func dealsText(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "\(count) сделок" }
        if mod10 == 1 { return "\(count) сделка" }
        if mod10 >= 2 && mod10 <= 4 { return "\(count) сделки" }
        return "\(count) сделок"
    }

    private func rText(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0R" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f", abs(value)) + "R"
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return .green }
        if value < -0.05 { return .red }
        return .secondary
    }
}

// MARK: - Week bars

struct WeekBars: View {
    let days: [WidgetData.WeekDay]
    let showLabels: Bool
    /// Высота области столбиков; для больших виджетов её увеличивают.
    var barArea: CGFloat? = nil

    private var maxMagnitude: Double {
        max(days.map { abs($0.r) }.max() ?? 0, 0.1)
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(barTint(day.r))
                            .frame(width: 9, height: barHeight(day.r))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight, alignment: .bottom)
                }
            }

            if showLabels {
                HStack(spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        Text(day.label)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var rowHeight: CGFloat {
        barArea ?? (showLabels ? 44 : 20)
    }

    private var barsHeight: CGFloat {
        barArea ?? (showLabels ? 40 : 18)
    }

    private func barHeight(_ value: Double) -> CGFloat {
        guard abs(value) >= 0.05 else { return 3 }
        return max(CGFloat(abs(value) / maxMagnitude) * barsHeight, 4)
    }

    private func barTint(_ value: Double) -> Color {
        if value > 0.05 { return .green }
        if value < -0.05 { return .red }
        return Color.white.opacity(0.18)
    }
}

// MARK: - Widget

struct NextTradeWidget: Widget {
    let kind: String = "com.organizationName.ICT-Checklist.ictchecklistwidgetextension.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTradeProvider()) { entry in
            NextTradeEntryView(entry: entry)
        }
        .configurationDisplayName("Следующая сделка")
        .description("Ступень Risk Ladder, риск на сделку и накопленные R.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WeekStatsWidget: Widget {
    let kind: String = "com.organizationName.ICT-Checklist.ictchecklistwidgetextension.weekly"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekStatsProvider()) { entry in
            WeekStatsEntryView(entry: entry)
        }
        .configurationDisplayName("Итоги недели")
        .description("Суммарный R за 7 дней, win rate, сделки и R по дням недели.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct ICT_ChecklistWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        NextTradeWidget()
        WeekStatsWidget()
        CycleWidget()
        CycleLiveActivity()
    }
}



// MARK: - Cycle activity attributes

/// Повтор объявления из приложения: ActivityKit сопоставляет активность
/// по имени типа, поэтому обе копии совпадают по полям.
struct CycleActivityAttributes: ActivityAttributes {
    var cycleStart: Date

    struct ContentState: Codable, Hashable {
        var cycleEnd: Date
        var tradesToday: Int
        var maxTrades: Int
        var rToday: Double
        var maxLossR: Double
        var limitsEnabled: Bool

        var openSymbol: String?
        var openDirection: String?
        var openIsBE: Bool
        var openPrice: Double?
        var toTargetR: Double?
        var toStopR: Double?
    }
}

private func cycleRText(_ value: Double?) -> String {
    guard let value else { return "—" }
    guard abs(value) >= 0.05 else { return "0.0R" }
    let sign = value > 0 ? "+" : "\u{2212}"
    return sign + String(format: "%.1f", abs(value)) + "R"
}

private func cycleRColor(_ value: Double?) -> Color {
    guard let value else { return .secondary }
    if value > 0.05 { return .green }
    if value < -0.05 { return .red }
    return .secondary
}

// MARK: - Lock screen

struct CycleLockScreenView: View {
    let state: CycleActivityAttributes.ContentState

    private var tradesText: String {
        state.limitsEnabled ? "\(state.tradesToday)/\(state.maxTrades)" : "\(state.tradesToday)"
    }

    private var rLeft: Double {
        max(state.maxLossR + min(state.rToday, 0), 0)
    }

    private var directionColor: Color {
        state.openDirection == "LONG" ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("ЦИКЛ")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                countdown
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                metric(title: "СДЕЛКИ", value: tradesText, tint: .white)
                metric(title: "R", value: cycleRText(state.rToday), tint: cycleRColor(state.rToday))

                if state.limitsEnabled {
                    metric(
                        title: "ДО ЛИМИТА",
                        value: cycleRText(rLeft),
                        tint: cycleRColor(rLeft)
                    )
                }
            }

            openRow
        }
        .padding(16)
    }

    @ViewBuilder
    private var countdown: some View {
        if state.cycleEnd > .now {
            Text(timerInterval: Date.now...state.cycleEnd, countsDown: true)
        } else {
            Text("цикл закрыт")
        }
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }

    @ViewBuilder
    private var openRow: some View {
        if let symbol = state.openSymbol {
            HStack(spacing: 8) {
                Text(symbol)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(state.openDirection ?? "")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(directionColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(directionColor.opacity(0.18)))

                if state.openIsBE {
                    Text("BE")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 6)

                Text("TP \(cycleRText(state.toTargetR))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)

                Text("SL \(cycleRText(state.toStopR))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        } else {
            Text("Открытой сделки нет")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Live Activity

struct CycleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CycleActivityAttributes.self) { context in
            CycleLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let end = max(state.cycleEnd, Date.now)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("ЦИКЛ", systemImage: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(summary(state))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Text(state.openSymbol ?? "Открытой сделки нет")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        if state.openSymbol != nil {
                            Text("TP \(cycleRText(state.toTargetR))")
                                .foregroundStyle(.green)
                            Text("SL \(cycleRText(state.toStopR))")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(timerInterval: Date.now...end, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(nil)
            .keylineTint(.white)
        }
    }

    private func summary(_ state: CycleActivityAttributes.ContentState) -> String {
        let trades = state.limitsEnabled
            ? "сделки \(state.tradesToday)/\(state.maxTrades)"
            : "сделок \(state.tradesToday)"
        return "\(trades) · \(cycleRText(state.rToday))"
    }
}

// MARK: - Cycle widget entry

struct CycleEntry: TimelineEntry {
    let date: Date
    let cycleEnd: Date?
    let tradesToday: Int
    let maxTrades: Int
    let limitsEnabled: Bool
    let rToday: Double
    let maxLossR: Double
    let openSymbol: String?
    let openDirection: String?
    let openIsBE: Bool
    let toTargetR: Double?
    let toStopR: Double?

    static var empty: CycleEntry {
        CycleEntry(
            date: .now,
            cycleEnd: nil,
            tradesToday: 0,
            maxTrades: 2,
            limitsEnabled: true,
            rToday: 0,
            maxLossR: 2,
            openSymbol: nil,
            openDirection: nil,
            openIsBE: false,
            toTargetR: nil,
            toStopR: nil
        )
    }
}

// MARK: - Cycle provider

struct CycleProvider: TimelineProvider {
    func placeholder(in context: Context) -> CycleEntry {
        CycleEntry(
            date: .now,
            cycleEnd: Date().addingTimeInterval(2 * 3600),
            tradesToday: 1,
            maxTrades: 2,
            limitsEnabled: true,
            rToday: -1,
            maxLossR: 2,
            openSymbol: "XAUUSD",
            openDirection: "LONG",
            openIsBE: false,
            toTargetR: 1.8,
            toStopR: 0.9
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func loadEntry() -> CycleEntry {
        guard let payload = WidgetData.load() else { return .empty }
        return CycleEntry(
            date: payload.updatedAt,
            cycleEnd: payload.cycleEnd,
            tradesToday: payload.cycleTrades ?? 0,
            maxTrades: payload.cycleMaxTrades ?? 2,
            limitsEnabled: payload.cycleLimits ?? false,
            rToday: payload.cycleR ?? 0,
            maxLossR: payload.cycleMaxR ?? 2,
            openSymbol: payload.openSymbol,
            openDirection: payload.openDirection,
            openIsBE: payload.openIsBE ?? false,
            toTargetR: payload.openTargetR,
            toStopR: payload.openStopR
        )
    }
}

// MARK: - Cycle widget view

struct CycleEntryView: View {
    let entry: CycleEntry

    @Environment(\.widgetFamily) private var family

    private var tradesText: String {
        entry.limitsEnabled ? "\(entry.tradesToday)/\(entry.maxTrades)" : "\(entry.tradesToday)"
    }

    private var rLeft: Double {
        max(entry.maxLossR + min(entry.rToday, 0), 0)
    }

    private var directionColor: Color {
        entry.openDirection == "LONG" ? .green : .red
    }

    @ViewBuilder
    var body: some View {
        if let cycleEnd = entry.cycleEnd, cycleEnd > .now {
            switch family {
            case .accessoryRectangular:
                accessoryRectangular(end: cycleEnd)
            case .accessoryInline:
                accessoryInline(end: cycleEnd)
            case .systemLarge:
                largeBody(end: cycleEnd).widgetContainerBackground()
            case .systemMedium:
                mediumBody(end: cycleEnd).widgetContainerBackground()
            default:
                smallBody(end: cycleEnd).widgetContainerBackground()
            }
        } else {
            switch family {
            case .accessoryRectangular:
                accessoryEmpty
            case .accessoryInline:
                Text("Цикл не идёт")
            default:
                emptyBody.widgetContainerBackground()
            }
        }
    }

    private func accessoryRectangular(end: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ЦИКЛ")
                .font(.system(size: 10, weight: .semibold))
                .widgetAccentable()

            Text(timerInterval: Date.now...end, countsDown: true)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()

            HStack(spacing: 6) {
                Text("Сделки \(tradesText)")
                    .foregroundStyle(.secondary)
                Text(cycleRText(entry.rToday))
                    .foregroundStyle(cycleRColor(entry.rToday))
            }
            .font(.system(size: 10.5, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessoryInline(end: Date) -> some View {
        Text("Цикл до \(end.formatted(date: .omitted, time: .shortened)) · \(tradesText) · \(cycleRText(entry.rToday))")
    }

    private var accessoryEmpty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ЦИКЛ")
                .font(.system(size: 10, weight: .semibold))
                .widgetAccentable()
            Text("Не идёт")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallBody(end: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ЦИКЛ ДНЯ")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(timerInterval: Date.now...end, countsDown: true)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("до конца цикла")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("Сделки \(tradesText)")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(cycleRText(entry.rToday))
                    .foregroundStyle(cycleRColor(entry.rToday))
            }
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func mediumBody(end: Date) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ЦИКЛ ДНЯ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(timerInterval: Date.now...end, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("до конца цикла")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text("Сделки \(tradesText)")
                        .foregroundStyle(.white)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(cycleRText(entry.rToday))
                        .foregroundStyle(cycleRColor(entry.rToday))
                    if entry.limitsEnabled {
                        Text("· до лимита \(cycleRText(rLeft))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11.5, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let symbol = entry.openSymbol {
                    HStack(spacing: 6) {
                        Text(symbol)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(entry.openDirection ?? "")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(directionColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(directionColor.opacity(0.18)))

                        if entry.openIsBE {
                            Text("BE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }

                    Text("TP \(cycleRText(entry.toTargetR)) · SL \(cycleRText(entry.toStopR))")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Открытой сделки нет")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func largeBody(end: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("ЦИКЛ ДНЯ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("до \(end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(timerInterval: Date.now...end, countsDown: true)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("до конца цикла")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                WidgetStatCell(title: "Сделки", value: tradesText)

                WidgetStatCell(
                    title: "Результат",
                    value: cycleRText(entry.rToday),
                    tint: cycleRColor(entry.rToday)
                )

                if entry.limitsEnabled {
                    WidgetStatCell(title: "До лимита", value: cycleRText(rLeft), tint: .secondary)
                }
            }

            Spacer(minLength: 0)

            openTradeBlock
        }
    }

    @ViewBuilder
    private var openTradeBlock: some View {
        if let symbol = entry.openSymbol {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(symbol)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(entry.openDirection ?? "")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(directionColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(directionColor.opacity(0.18)))

                    if entry.openIsBE {
                        Text("BE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    Spacer(minLength: 0)
                }

                Text("TP \(cycleRText(entry.toTargetR)) · SL \(cycleRText(entry.toStopR))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        } else {
            Text("Открытой сделки нет")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ЦИКЛ ДНЯ")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            Text("Сейчас нет")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("Цикл не идёт")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Cycle widget

struct CycleWidget: Widget {
    let kind: String = "com.organizationName.ICT-Checklist.ictchecklistwidgetextension.cycle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CycleProvider()) { entry in
            CycleEntryView(entry: entry)
        }
        .configurationDisplayName("Цикл дня")
        .description("Сколько времени до конца цикла, сделки и R до дневного лимита, открытая сделка.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

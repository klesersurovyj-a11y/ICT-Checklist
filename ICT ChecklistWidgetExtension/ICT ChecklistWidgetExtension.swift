//
//  ICT ChecklistWidgetExtension.swift
//  ICT Checklist
//

import WidgetKit
import SwiftUI

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

    private var accumuletedColor: Color {
        entry.accumulatedR >= 0 ? .green : .red
    }

    var body: some View {
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
        .widgetContainerBackground()
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

    var body: some View {
        if family == .systemMedium {
            mediumBody.widgetContainerBackground()
        } else {
            smallBody.widgetContainerBackground()
        }
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
                    .frame(height: showLabels ? 44 : 20, alignment: .bottom)
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

    private func barHeight(_ value: Double) -> CGFloat {
        let area = showLabels ? 40.0 : 18.0
        guard abs(value) >= 0.05 else { return 3 }
        return max(CGFloat(abs(value) / maxMagnitude) * area, 4)
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ICT_ChecklistWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        NextTradeWidget()
        WeekStatsWidget()
    }
}

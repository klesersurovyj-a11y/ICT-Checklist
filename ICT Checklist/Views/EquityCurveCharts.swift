//
//  EquityCurveCharts.swift
//  ICT Checklist
//
//  Графики кривой капитала и «подводной» кривой просадки.
//

import SwiftUI
import Charts

struct EquityChartView: View {
    let points: [EquityCurvePoint]
    var showXAxis: Bool = true

    @State private var selectedDate: Date?

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Дата", point.date),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("Процент", point.percent)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.green.opacity(0.22), Theme.green.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Дата", point.date),
                    y: .value("Процент", point.percent)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.green)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let last = points.last {
                PointMark(
                    x: .value("Дата", last.date),
                    y: .value("Процент", last.percent)
                )
                .foregroundStyle(Theme.green)
                .symbolSize(38)
            }

            if let point = selectedPoint {
                RuleMark(x: .value("Дата", point.date))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Дата", point.date),
                    y: .value("Процент", point.percent)
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(46)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            if showXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(label(for: date))
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            } else {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.05))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(percentLabel(percent))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: domain)
        .chartLegend(.hidden)
        .chartSweep(delay: 0.2)
        .overlay(alignment: .topLeading) {
            if let point = selectedPoint {
                tooltip(
                    date: point.date,
                    value: percentLabel(point.percent),
                    tint: point.percent >= 0 ? Theme.green : Theme.red
                )
            }
        }
    }

    private var selectedPoint: EquityCurvePoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func tooltip(date: Date, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .glassPanel(cornerRadius: 10)
        .padding(.leading, 6)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }

    private var domain: ClosedRange<Double> {
        var values = points.map(\.percent)
        values.append(0)
        guard let low = values.min(), let high = values.max() else { return -1...1 }
        let span = max(high - low, 1)
        return (low - span * 0.12)...(high + span * 0.12)
    }

    private func percentLabel(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0%" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.0f%%", abs(value))
    }

    private func label(for date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

struct DrawdownChartView: View {
    let points: [DrawdownPoint]
    var showXAxis: Bool = true

    @State private var selectedDate: Date?

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Дата", point.date),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("Просадка", -point.percent)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.red.opacity(0.01), Theme.red.opacity(0.30)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Дата", point.date),
                    y: .value("Просадка", -point.percent)
                )
                .foregroundStyle(Theme.red)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }

            if let point = selectedPoint {
                RuleMark(x: .value("Дата", point.date))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Дата", point.date),
                    y: .value("Просадка", -point.percent)
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(44)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            if showXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            } else {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.05))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(percentLabel(percent))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: domain)
        .chartLegend(.hidden)
        .chartSweep(delay: 0.2)
        .overlay(alignment: .topLeading) {
            if let point = selectedPoint {
                tooltip(date: point.date, value: percentLabel(point.percent))
            }
        }
    }

    private var selectedPoint: DrawdownPoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func tooltip(date: Date, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.red)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .glassPanel(cornerRadius: 10)
        .padding(.leading, 6)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }

    private var domain: ClosedRange<Double> {
        let deepest = points.map(\.percent).max() ?? 0
        let bottom = min(deepest * 1.2, 1)
        return -bottom...0
    }

    private func percentLabel(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0%" }
        return "\u{2212}" + String(format: "%.0f%%", abs(value))
    }
}

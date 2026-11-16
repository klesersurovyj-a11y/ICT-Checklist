//
//  RSparkline.swift
//  ICT Checklist
//

import SwiftUI
import Charts

struct RSparkline: View {
    let values: [Double]
    var tint: Color = Theme.green

    private var domain: ClosedRange<Double> {
        guard let minimum = values.min(), let maximum = values.max() else { return -1...1 }
        let span = max(maximum - minimum, 0.5)
        return (minimum - span * 0.25)...(maximum + span * 0.25)
    }

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("i", index),
                    y: .value("R", value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.30), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("i", index),
                    y: .value("R", value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))

                if index == values.count - 1 {
                    PointMark(
                        x: .value("i", index),
                        y: .value("R", value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(34)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: domain)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}

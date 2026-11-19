//
//  EquityCurveImage.swift
//  ICT Checklist
//
//  Картинка «Капитал и просадка» для системного меню «Поделиться».
//

import SwiftUI
import UIKit

enum EquityCurveImage {
    @MainActor
    static func make(
        _ report: EquityCurveReport,
        scopeName: String,
        period: EquityCurvePeriod
    ) -> URL? {
        let content = EquityShareCard(report: report, scopeName: scopeName, period: period)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — капитал.png")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct EquityShareCard: View {
    let report: EquityCurveReport
    let scopeName: String
    let period: EquityCurvePeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ICT CHECKLIST · КАПИТАЛ")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Fmt.groupedMoney(report.capital)) · \(Fmt.signedPercent(report.totalPercent))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(scopeName) · \(period.rawValue.lowercased())")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            EquityChartView(points: report.points)
                .frame(height: 170)

            VStack(alignment: .leading, spacing: 6) {
                Text("Под водой")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                DrawdownChartView(points: report.drawdown)
                    .frame(height: 90)
            }

            HStack(spacing: 0) {
                shareStat(
                    "Макс. просадка",
                    value: report.maxDrawdownPercent > 0.05
                        ? "\u{2212}\(String(format: "%.1f%%", report.maxDrawdownPercent))"
                        : "0.0%",
                    tint: Theme.red
                )
                Spacer(minLength: 10)
                shareStat("Восстановление", value: recoveryText, tint: .white)
                Spacer(minLength: 10)
                shareStat(
                    "Лучший день",
                    value: report.bestDay.map { Fmt.signedPercent($0.percent) } ?? "—",
                    tint: Theme.green
                )
            }

            Divider()
                .overlay(Color.white.opacity(0.10))

            Text("ICT Checklist")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(22)
        .frame(width: 360, alignment: .leading)
        .background(Color(white: 0.03))
        .environment(\.colorScheme, .dark)
    }

    private var recoveryText: String {
        guard report.maxDrawdownPercent > 0.05 else { return "—" }
        return String(format: "%.1f", report.recoveryFactor)
    }

    private func shareStat(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

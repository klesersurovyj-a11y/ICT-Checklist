//
//  MonthReportImage.swift
//  ICT Checklist
//
//  Месячный отчёт одной картинкой для мессенджеров.
//

import SwiftUI
import UIKit

enum MonthReportImage {
    /// Ширина карточки в точках — от неё считается разрешение картинки.
    static let cardWidth: CGFloat = 360
    static let minPixelWidth: CGFloat = 720
    static let maxPixelWidth: CGFloat = 4320

    /// `pixelWidth` — ширина готового PNG в пикселях: масштаб рендера
    /// считается как ширина / ширина карточки, поэтому картинку можно
    /// делать от 720 до 4320 пикселей без изменения вёрстки.
    @MainActor
    static func make(_ report: MonthlyReport, pixelWidth: CGFloat = 1080) -> URL? {
        let width = min(max(pixelWidth, minPixelWidth), maxPixelWidth)

        let renderer = ImageRenderer(content: MonthReportCard(report: report))
        renderer.scale = max(1, width / cardWidth)
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: cardWidth, height: nil)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            return nil
        }

        let name = "ICT Checklist — \(report.label) \(Int(width)) px.png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Разрешение картинки месяца: три готовых варианта и своя ширина.
enum ImageExportResolution: String, CaseIterable, Identifiable {
    case standard
    case high
    case maximum
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Стандарт"
        case .high: return "Высокое"
        case .maximum: return "Максимум"
        case .custom: return "Своё"
        }
    }

    /// Ширина готовой картинки в пикселях; у «Своего» ширина задаётся вручную.
    var pixelWidth: CGFloat? {
        switch self {
        case .standard: return 1080
        case .high: return 1440
        case .maximum: return 2160
        case .custom: return nil
        }
    }

    var note: String {
        switch self {
        case .standard: return "для чата"
        case .high: return "по умолчанию"
        case .maximum: return "для печати"
        case .custom: return "своя ширина"
        }
    }
}

private struct MonthReportCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ICT CHECKLIST · MONTHLY REVIEW")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.4))

            Text(report.label)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("РЕЗУЛЬТАТ МЕСЯЦА")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.4))

                    Text(Fmt.r(report.totalR))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rColor(report.totalR))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("\(Fmt.deals(report.tradesCount)) · \(Fmt.tradingDays(report.tradingDays))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 74, height: 74)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 74, height: 74)
                    Text(report.grade)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 8) {
                tile("Win rate", "\(Int((report.winRate * 100).rounded()))%")
                tile("Сделки", "\(report.tradesCount)")
                tile("PF", report.profitFactor.map { String(format: "%.1f", $0) } ?? "—")
            }

            VStack(spacing: 8) {
                if let best = report.bestDay {
                    dayRow(title: "Лучший день", date: best.date, r: best.r)
                }
                if let worst = report.worstDay {
                    dayRow(title: "Худший день", date: worst.date, r: worst.r)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.edge.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text(report.edge.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )

            HStack {
                Text("Оценка \(report.totalScore) из 100")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer(minLength: 8)

                Text("ICT Checklist")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(22)
        .frame(width: 360, alignment: .leading)
        .background(Color(white: 0.03))
        .environment(\.colorScheme, .dark)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func dayRow(title: String, date: Date, r: Double) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))

            Text(Fmt.shortDay(date))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))

            Spacer(minLength: 0)

            Text(Fmt.r(r))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(r))
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Color(hex: 0x7BE3B0) }
        if value < -0.05 { return Color(hex: 0xFF8A8A) }
        return .white.opacity(0.7)
    }
}

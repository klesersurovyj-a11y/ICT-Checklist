//
//  WeeklyPDF.swift
//  ICT Checklist
//

import Foundation
import UIKit

struct WeeklyPDFData {
    struct Metric {
        let title: String
        let value: String
        let comparison: String?
    }

    struct Row {
        let day: String
        let symbol: String
        let direction: String
        let result: String
        let r: Double
    }

    let weekTitle: String
    let gainedR: Double
    let winRate: Double
    let tradesCount: Int
    let metrics: [Metric]
    let rows: [Row]
}

enum WeeklyPDF {
    static func make(_ data: WeeklyPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = data.weekTitle
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — разбор недели \(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44
                y = drawHeader(data, y: y)
                y = drawSummary(data, y: y)
                y = drawHeading("Блоки разбора", y: y)

                for metric in data.metrics {
                    if y > 740 {
                        pdf.beginPage()
                        y = 44
                    }
                    y = drawMetric(metric, y: y)
                }

                y += 10
                if y > 700 {
                    pdf.beginPage()
                    y = 44
                }
                y = drawHeading("Сделки недели", y: y)

                if data.rows.isEmpty {
                    _ = drawText(
                        "Сделок за неделю нет",
                        font: .systemFont(ofSize: 12),
                        color: UIColor.gray,
                        x: 40,
                        y: y
                    )
                } else {
                    for row in data.rows {
                        if y > 770 {
                            pdf.beginPage()
                            y = 44
                        }
                        y = drawRow(row, y: y)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Blocks

    private static func drawHeader(_ data: WeeklyPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "ICT Checklist",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        cursor += 18
        cursor = drawText(
            "Разбор недели",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor += 2
        cursor = drawText(
            data.weekTitle,
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor.darkGray,
            x: 40,
            y: cursor
        )
        cursor = drawText(
            "Сформирован \(Fmt.shortDay(.now))",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        return cursor + 20
    }

    private static func drawSummary(_ data: WeeklyPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "Итог недели",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        cursor += 18

        let tint = data.gainedR >= 0 ? UIColor.systemGreen : UIColor.systemRed
        cursor = drawText(
            rText(data.gainedR),
            font: .systemFont(ofSize: 40, weight: .bold),
            color: tint,
            x: 40,
            y: cursor
        )
        cursor += 2
        cursor = drawText(
            "\(data.tradesCount) \(Fmt.dealWord(data.tradesCount)) · \(Int((data.winRate * 100).rounded()))% win rate",
            font: .systemFont(ofSize: 11),
            color: UIColor.darkGray,
            x: 40,
            y: cursor
        )

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 12))
            context.addLine(to: CGPoint(x: 555, y: cursor + 12))
            context.strokePath()
        }

        return cursor + 28
    }

    private static func drawHeading(_ text: String, y: CGFloat) -> CGFloat {
        let cursor = drawText(
            text,
            font: .systemFont(ofSize: 16, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: y
        )
        return cursor + 8
    }

    private static func drawMetric(_ metric: WeeklyPDFData.Metric, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            metric.title,
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor(white: 0.15, alpha: 1),
            x: 40,
            y: cursor,
            width: 340
        )
        _ = drawText(
            metric.value,
            font: .systemFont(ofSize: 12, weight: .bold),
            color: UIColor.black,
            x: 390,
            y: cursor,
            width: 165,
            alignment: .right
        )
        cursor += 18

        if let comparison = metric.comparison {
            cursor = drawText(
                comparison,
                font: .systemFont(ofSize: 9.5, weight: .medium),
                color: UIColor.gray,
                x: 40,
                y: cursor
            )
            cursor += 2
        }

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 2))
            context.addLine(to: CGPoint(x: 555, y: cursor + 2))
            context.strokePath()
        }
        return cursor + 10
    }

    private static func drawRow(_ row: WeeklyPDFData.Row, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "\(row.symbol) · \(row.direction) · \(row.result)",
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        let color = row.r > 0 ? UIColor.systemGreen : (row.r < 0 ? UIColor.systemRed : UIColor.gray)
        _ = drawText(
            rText(row.r),
            font: .systemFont(ofSize: 12, weight: .bold),
            color: color,
            x: 390,
            y: cursor,
            width: 165,
            alignment: .right
        )
        cursor += 16
        cursor = drawText(
            row.day,
            font: .systemFont(ofSize: 9),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 8))
            context.addLine(to: CGPoint(x: 555, y: cursor + 8))
            context.strokePath()
        }
        return cursor + 18
    }

    // MARK: - Helpers

    private static func rText(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0R" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f", abs(value)) + "R"
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 515,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounds = CGRect(x: x, y: y, width: width, height: font.lineHeight + 2)
        (text as NSString).draw(in: bounds, withAttributes: attributes)
        return y + font.lineHeight + 2
    }
}

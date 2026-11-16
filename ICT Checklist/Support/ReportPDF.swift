//
//  ReportPDF.swift
//  ICT Checklist
//

import Foundation
import UIKit

struct ReportPDFData {
    struct Row {
        let symbol: String
        let direction: String
        let day: String
        let result: String
        let r: Double
    }

    let monthTitle: String
    let totalR: Double
    let winRate: Double
    let profitFactor: Double?
    let averageR: Double
    let tradingDays: Int
    let tradesCount: Int
    let bestDay: (date: String, r: Double)?
    let worstDay: (date: String, r: Double)?
    let rows: [Row]
}

enum ReportPDF {
    static func make(_ data: ReportPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = data.monthTitle.replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — отчёт \(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44
                y = drawHeader(data, y: y)
                y = drawSummary(data, y: y)
                y = drawDays(data, y: y)
                y = drawHeading("Сделки месяца", y: y)

                if data.rows.isEmpty {
                    _ = drawText(
                        "Сделок за месяц нет",
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

    private static func drawHeader(_ data: ReportPDFData, y: CGFloat) -> CGFloat {
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
            "Отчёт за \(data.monthTitle)",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor += 4
        cursor = drawText(
            "Сформирован \(Fmt.shortDay(.now))",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        return cursor + 20
    }

    private static func drawSummary(_ data: ReportPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "Суммарный R",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        cursor += 18

        let rColor = data.totalR >= 0 ? UIColor.systemGreen : UIColor.systemRed
        cursor = drawText(
            rText(data.totalR),
            font: .systemFont(ofSize: 40, weight: .bold),
            color: rColor,
            x: 40,
            y: cursor
        )
        cursor += 2
        cursor = drawText(
            "\(Fmt.tradingDays(data.tradingDays)) · \(data.tradesCount) \(Fmt.dealWord(data.tradesCount))",
            font: .systemFont(ofSize: 11),
            color: UIColor.darkGray,
            x: 40,
            y: cursor
        )
        cursor += 6

        let profitFactor = data.profitFactor.map { String(format: "%.1f", $0) } ?? "—"
        let line = "Win rate \(Int((data.winRate * 100).rounded()))%   ·   Profit factor \(profitFactor)   ·   Средний R \(Fmt.signed(data.averageR, digits: 2))"
        cursor = drawText(
            line,
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor.black,
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

        return cursor + 26
    }

    private static func drawDays(_ data: ReportPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        let best = data.bestDay.map { "\(rText($0.r)) · \($0.date)" } ?? "—"
        let worst = data.worstDay.map { "\(rText($0.r)) · \($0.date)" } ?? "—"
        cursor = drawText(
            "Лучший день: \(best)",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor = drawText(
            "Худший день: \(worst)",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        return cursor + 16
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

    private static func drawRow(_ row: ReportPDFData.Row, y: CGFloat) -> CGFloat {
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

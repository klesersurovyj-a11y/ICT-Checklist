//
//  DayReviewPDF.swift
//  ICT Checklist
//

import Foundation
import UIKit

struct DayReviewPDFData {
    struct Row {
        let title: String
        let value: String
    }

    struct Section {
        let title: String
        let rows: [Row]
    }

    struct TradeRow {
        let symbol: String
        let direction: String
        let result: String
        let r: Double
    }

    let dayTitle: String
    let weekTitle: String
    let dayR: Double
    let hasResult: Bool
    let tradesCount: Int
    let winRate: Double
    let tp: Int
    let sl: Int
    let be: Int
    let sections: [Section]
    let trades: [TradeRow]
    let journalMood: String?
    let journalNote: String?
}

enum DayReviewPDF {
    static func make(_ data: DayReviewPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = fileDateFormatter.string(from: .now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — разбор дня \(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44
                y = drawHeader(data, y: y)
                y = drawSummary(data, y: y)

                for section in data.sections {
                    if y > 700 {
                        pdf.beginPage()
                        y = 44
                    }
                    y = drawHeading(section.title, y: y)
                    for row in section.rows {
                        if y > 760 {
                            pdf.beginPage()
                            y = 44
                        }
                        y = drawRow(row, y: y)
                    }
                    y += 10
                }

                if !data.trades.isEmpty {
                    if y > 700 {
                        pdf.beginPage()
                        y = 44
                    }
                    y = drawHeading("Сделки дня", y: y)
                    for trade in data.trades {
                        if y > 760 {
                            pdf.beginPage()
                            y = 44
                        }
                        y = drawTrade(trade, y: y)
                    }
                    y += 10
                }

                if data.journalMood != nil || data.journalNote != nil {
                    if y > 700 {
                        pdf.beginPage()
                        y = 44
                    }
                    y = drawHeading("Дневник", y: y)
                    if let mood = data.journalMood {
                        y = drawWrapped("Настроение: \(mood)", font: .systemFont(ofSize: 11.5), color: UIColor.black, x: 40, width: 515, y: y)
                    }
                    if let note = data.journalNote, !note.isEmpty {
                        y += 2
                        y = drawWrapped(note, font: .systemFont(ofSize: 11.5), color: UIColor(white: 0.2, alpha: 1), x: 40, width: 515, y: y)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Blocks

    private static func drawHeader(_ data: DayReviewPDFData, y: CGFloat) -> CGFloat {
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
            "Разбор дня",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor += 2
        if !data.weekTitle.isEmpty {
            cursor = drawText(
                "\(data.dayTitle) · \(data.weekTitle)",
                font: .systemFont(ofSize: 12, weight: .medium),
                color: UIColor.darkGray,
                x: 40,
                y: cursor
            )
        } else {
            cursor = drawText(
                data.dayTitle,
                font: .systemFont(ofSize: 12, weight: .medium),
                color: UIColor.darkGray,
                x: 40,
                y: cursor
            )
        }
        cursor = drawText(
            "Сформирован \(Fmt.shortDay(.now))",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        return cursor + 18
    }

    private static func drawSummary(_ data: DayReviewPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "Итог дня",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        cursor += 18

        let tint: UIColor
        if !data.hasResult {
            tint = UIColor.gray
        } else {
            tint = data.dayR >= 0 ? UIColor.systemGreen : UIColor.systemRed
        }
        cursor = drawText(
            data.hasResult ? rText(data.dayR) : "—",
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
        cursor = drawText(
            "TP \(data.tp)   ·   SL \(data.sl)   ·   BE \(data.be)",
            font: .systemFont(ofSize: 12, weight: .semibold),
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

        return cursor + 28
    }

    private static func drawHeading(_ text: String, y: CGFloat) -> CGFloat {
        let cursor = drawText(
            text,
            font: .systemFont(ofSize: 15, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: y
        )
        return cursor + 4
    }

    private static func drawRow(_ row: DayReviewPDFData.Row, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            row.title,
            font: .systemFont(ofSize: 12),
            color: UIColor(white: 0.15, alpha: 1),
            x: 40,
            y: cursor,
            width: 340
        )
        _ = drawText(
            row.value,
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: UIColor.black,
            x: 390,
            y: cursor,
            width: 165,
            alignment: .right
        )
        cursor += 18

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 2))
            context.addLine(to: CGPoint(x: 555, y: cursor + 2))
            context.strokePath()
        }
        return cursor + 8
    }

    private static func drawTrade(_ trade: DayReviewPDFData.TradeRow, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = drawText(
            "\(trade.symbol) · \(trade.direction) · \(trade.result)",
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        let color = trade.r > 0 ? UIColor.systemGreen : (trade.r < 0 ? UIColor.systemRed : UIColor.gray)
        _ = drawText(
            rText(trade.r),
            font: .systemFont(ofSize: 12, weight: .bold),
            color: color,
            x: 390,
            y: cursor,
            width: 165,
            alignment: .right
        )
        cursor += 18

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 2))
            context.addLine(to: CGPoint(x: 555, y: cursor + 2))
            context.strokePath()
        }
        return cursor + 8
    }

    // MARK: - Helpers

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

    @discardableResult
    private static func drawWrapped(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        width: CGFloat,
        y: CGFloat
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(
            with: CGRect(x: x, y: y, width: width, height: ceil(rect.height) + 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return y + ceil(rect.height) + 2
    }
}

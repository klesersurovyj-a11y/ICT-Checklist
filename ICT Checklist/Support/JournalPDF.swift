//
//  JournalPDF.swift
//  ICT Checklist
//

import Foundation
import UIKit

struct JournalPDFData {
    struct Row {
        let dayTitle: String
        let mood: String
        let note: String
        let improve: String
    }

    let monthTitle: String
    let rows: [Row]
}

enum JournalPDF {
    static func make(_ data: JournalPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = data.monthTitle.replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — дневник \(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44
                y = drawHeader(data, y: y)

                for row in data.rows {
                    if y > 740 {
                        pdf.beginPage()
                        y = 44
                    }
                    y = drawEntry(row, y: y)
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Blocks

    private static func drawHeader(_ data: JournalPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        cursor = drawText(
            "ICT Checklist",
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )
        cursor += 14
        cursor = drawText(
            "Дневник трейдера",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor += 2
        cursor = drawText(
            "\(data.monthTitle) · \(data.rows.count) \(entriesWord(data.rows.count))",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: UIColor.darkGray,
            x: 40,
            y: cursor
        )
        cursor = drawText(
            "Сформирован \(Fmt.day(.now))",
            font: .systemFont(ofSize: 10),
            color: UIColor.gray,
            x: 40,
            y: cursor
        )

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 10))
            context.addLine(to: CGPoint(x: 555, y: cursor + 10))
            context.strokePath()
        }

        return cursor + 24
    }

    private static func drawEntry(_ row: JournalPDFData.Row, y: CGFloat) -> CGFloat {
        let dateFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let moodFont = UIFont.systemFont(ofSize: 11, weight: .medium)

        _ = drawText(
            row.dayTitle,
            font: dateFont,
            color: UIColor.black,
            x: 40,
            y: y,
            width: 300
        )
        _ = drawText(
            row.mood,
            font: moodFont,
            color: UIColor.darkGray,
            x: 340,
            y: y,
            width: 215,
            alignment: .right
        )

        var cursor = y + max(dateFont.lineHeight, moodFont.lineHeight) + 4

        if row.note.isEmpty {
            cursor = drawText(
                "Без заметки",
                font: .systemFont(ofSize: 12),
                color: UIColor.gray,
                x: 40,
                y: cursor
            )
        } else {
            cursor = drawWrapped(
                row.note,
                font: .systemFont(ofSize: 12),
                color: UIColor.black,
                x: 40,
                width: 515,
                y: cursor
            )
        }

        if !row.improve.isEmpty {
            cursor += 2
            cursor = drawWrapped(
                "Что улучшить: \(row.improve)",
                font: .systemFont(ofSize: 11),
                color: UIColor.darkGray,
                x: 40,
                width: 515,
                y: cursor
            )
        }

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 10))
            context.addLine(to: CGPoint(x: 555, y: cursor + 10))
            context.strokePath()
        }

        return cursor + 24
    }

    // MARK: - Helpers

    private static func entriesWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "записей" }
        if mod10 == 1 { return "запись" }
        if mod10 >= 2 && mod10 <= 4 { return "записи" }
        return "записей"
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

//
//  BrainPDF.swift
//  ICT Checklist
//

import Foundation
import UIKit

struct BrainPDFData {
    struct Row {
        let kind: String
        let title: String
        let topic: String
        let summary: String
        let keyTitle: String
        let keyPoints: [String]
        let benefits: String
        let conclusions: String
    }

    let dateTitle: String
    let rows: [Row]
}

enum BrainPDF {
    static func make(_ data: BrainPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = data.dateTitle
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — Second Brain \(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44
                y = drawHeader(data, y: y)

                for row in data.rows {
                    if y > 680 {
                        pdf.beginPage()
                        y = 44
                    }

                    for block in blocks(for: row) {
                        if y > 740 {
                            pdf.beginPage()
                            y = 44
                        }
                        y = drawBlock(block, y: y)
                    }

                    y = drawSeparator(y: y) + 14
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Blocks

    private struct Block {
        let text: String
        let font: UIFont
        let color: UIColor
        let spacingAfter: CGFloat
        let indent: CGFloat
    }

    private static func blocks(for row: BrainPDFData.Row) -> [Block] {
        var blocks: [Block] = [
            Block(
                text: row.kind.uppercased(),
                font: .systemFont(ofSize: 9, weight: .semibold),
                color: UIColor.gray,
                spacingAfter: 2,
                indent: 0
            ),
            Block(
                text: row.title,
                font: .systemFont(ofSize: 18, weight: .bold),
                color: UIColor.black,
                spacingAfter: 3,
                indent: 0
            )
        ]

        if !row.topic.isEmpty {
            blocks.append(
                Block(
                    text: "Тема: \(row.topic)",
                    font: .systemFont(ofSize: 11.5, weight: .medium),
                    color: UIColor.darkGray,
                    spacingAfter: 8,
                    indent: 0
                )
            )
        }

        if !row.summary.isEmpty {
            blocks.append(
                Block(
                    text: row.summary,
                    font: .systemFont(ofSize: 12),
                    color: UIColor(white: 0.12, alpha: 1),
                    spacingAfter: 8,
                    indent: 0
                )
            )
        }

        if !row.keyPoints.isEmpty {
            blocks.append(
                Block(
                    text: row.keyTitle,
                    font: .systemFont(ofSize: 11, weight: .semibold),
                    color: UIColor.black,
                    spacingAfter: 3,
                    indent: 0
                )
            )
            for point in row.keyPoints {
                blocks.append(
                    Block(
                        text: "• \(point)",
                        font: .systemFont(ofSize: 11.5),
                        color: UIColor(white: 0.12, alpha: 1),
                        spacingAfter: 3,
                        indent: 12
                    )
                )
            }
            blocks.append(
                Block(
                    text: "",
                    font: .systemFont(ofSize: 4),
                    color: .clear,
                    spacingAfter: 5,
                    indent: 0
                )
            )
        }

        if !row.benefits.isEmpty {
            blocks.append(
                Block(
                    text: "Польза: \(row.benefits)",
                    font: .systemFont(ofSize: 11.5),
                    color: UIColor(white: 0.2, alpha: 1),
                    spacingAfter: 6,
                    indent: 0
                )
            )
        }

        if !row.conclusions.isEmpty {
            blocks.append(
                Block(
                    text: "Выводы: \(row.conclusions)",
                    font: .systemFont(ofSize: 11.5, weight: .medium),
                    color: UIColor(white: 0.12, alpha: 1),
                    spacingAfter: 6,
                    indent: 0
                )
            )
        }

        return blocks
    }

    // MARK: - Drawing

    private static func drawHeader(_ data: BrainPDFData, y: CGFloat) -> CGFloat {
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
            "Second Brain",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: UIColor.black,
            x: 40,
            y: cursor
        )
        cursor += 2
        cursor = drawText(
            "\(data.dateTitle) · \(data.rows.count) \(entriesWord(data.rows.count))",
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

    @discardableResult
    private static func drawBlock(_ block: Block, y: CGFloat) -> CGFloat {
        guard !block.text.isEmpty else { return y + block.spacingAfter }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: block.font,
            .foregroundColor: block.color,
            .paragraphStyle: paragraph
        ]
        let x: CGFloat = 40 + block.indent
        let width: CGFloat = 515 - block.indent

        let rect = (block.text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        (block.text as NSString).draw(
            with: CGRect(x: x, y: y, width: width, height: ceil(rect.height) + 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return y + ceil(rect.height) + 2 + block.spacingAfter
    }

    private static func drawSeparator(y: CGFloat) -> CGFloat {
        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.90, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: y + 2))
            context.addLine(to: CGPoint(x: 555, y: y + 2))
            context.strokePath()
        }
        return y + 4
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
}

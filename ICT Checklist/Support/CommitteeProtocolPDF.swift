//
//  CommitteeProtocolPDF.swift
//  ICT Checklist
//
//  Протокол заседания комитета в PDF: повестка, решения, нарушения и гипотезы.
//

import Foundation
import UIKit

struct CommitteeProtocolPDFData {
    let weekLabel: String
    let mandateVersion: Int
    let weekR: Double
    let items: [(title: String, detail: String)]
    let decisions: [CommitteeDecision]
    let note: String
    let violations: [String]
    let hypotheses: [String]
}

enum CommitteeProtocolPDF {
    static func make(_ data: CommitteeProtocolPDFData) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeWeek = data.weekLabel.replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — протокол \(safeWeek).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                pdf.beginPage()
                var y: CGFloat = 44

                y = drawHeader(data, y: y)

                func newPageIfNeeded(_ cursor: CGFloat) -> CGFloat {
                    if cursor > 740 {
                        pdf.beginPage()
                        return 44
                    }
                    return cursor
                }

                y = section("Повестка", y: y, x: 40)
                if data.items.isEmpty {
                    y = text("Пунктов нет.", font: .systemFont(ofSize: 11), color: .darkGray, x: 40, y: y, width: 515)
                } else {
                    for (index, item) in data.items.enumerated() {
                        y = newPageIfNeeded(y)
                        y = text(
                            "\(index + 1). \(item.title)",
                            font: .systemFont(ofSize: 12, weight: .semibold),
                            color: .black,
                            x: 40,
                            y: y,
                            width: 515
                        )
                        y = text(item.detail, font: .systemFont(ofSize: 10.5), color: .darkGray, x: 52, y: y + 1, width: 503)
                        y += 6
                    }
                }

                y = newPageIfNeeded(y + 8)
                y = section("Решения", y: y + 4, x: 40)
                if data.decisions.isEmpty {
                    y = text("Решений нет.", font: .systemFont(ofSize: 11), color: .darkGray, x: 40, y: y, width: 515)
                } else {
                    for decision in data.decisions {
                        y = newPageIfNeeded(y)
                        y = text(
                            "• \(decision.text)",
                            font: .systemFont(ofSize: 11.5),
                            color: .black,
                            x: 40,
                            y: y,
                            width: 515
                        )
                        y = text(
                            "\(decision.action.rawValue) · \(Fmt.shortDay(decision.createdAt))",
                            font: .systemFont(ofSize: 10),
                            color: .gray,
                            x: 52,
                            y: y,
                            width: 503
                        )
                        if !decision.note.isEmpty {
                            y = text(decision.note, font: .systemFont(ofSize: 10), color: .darkGray, x: 52, y: y, width: 503)
                        }
                        y += 4
                    }
                }

                if !data.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    y = newPageIfNeeded(y + 6)
                    y = section("Заметка к протоколу", y: y + 2, x: 40)
                    y = text(data.note, font: .systemFont(ofSize: 11), color: .darkGray, x: 40, y: y, width: 515)
                }

                y = newPageIfNeeded(y + 8)
                y = section("Нарушения мандата", y: y + 4, x: 40)
                if data.violations.isEmpty {
                    y = text("Нарушений нет.", font: .systemFont(ofSize: 11), color: .darkGray, x: 40, y: y, width: 515)
                } else {
                    for line in data.violations {
                        y = newPageIfNeeded(y)
                        y = text("• \(line)", font: .systemFont(ofSize: 10.5), color: .black, x: 40, y: y, width: 515)
                    }
                }

                y = newPageIfNeeded(y + 8)
                y = section("Гипотезы к проверке", y: y + 4, x: 40)
                if data.hypotheses.isEmpty {
                    y = text("Гипотез на проверке нет.", font: .systemFont(ofSize: 11), color: .darkGray, x: 40, y: y, width: 515)
                } else {
                    for line in data.hypotheses {
                        y = newPageIfNeeded(y)
                        y = text("• \(line)", font: .systemFont(ofSize: 10.5), color: .black, x: 40, y: y, width: 515)
                    }
                }

                _ = text(
                    "Сформирован \(Fmt.day(.now)) · ICT Checklist",
                    font: .systemFont(ofSize: 9),
                    color: .gray,
                    x: 40,
                    y: 800,
                    width: 515
                )
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Blocks

    private static func drawHeader(_ data: CommitteeProtocolPDFData, y: CGFloat) -> CGFloat {
        var cursor = y
        cursor = text("ICT Checklist", font: .systemFont(ofSize: 10, weight: .semibold), color: .gray, x: 40, y: cursor, width: 515)
        cursor += 2
        cursor = text("Протокол заседания комитета", font: .systemFont(ofSize: 24, weight: .bold), color: .black, x: 40, y: cursor, width: 515)
        cursor += 1
        cursor = text(
            "Неделя \(data.weekLabel) · мандат v\(data.mandateVersion)",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .darkGray,
            x: 40,
            y: cursor,
            width: 515
        )
        cursor = text(
            "Итог недели: \(Fmt.r(data.weekR)) · сформирован \(Fmt.day(.now))",
            font: .systemFont(ofSize: 11),
            color: .darkGray,
            x: 40,
            y: cursor,
            width: 515
        )

        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 40, y: cursor + 10))
            context.addLine(to: CGPoint(x: 555, y: cursor + 10))
            context.strokePath()
        }

        return cursor + 22
    }

    private static func section(_ title: String, y: CGFloat, x: CGFloat) -> CGFloat {
        let cursor = text(
            title.uppercased(),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: UIColor(white: 0.35, alpha: 1),
            x: x,
            y: y,
            width: 515
        )
        return cursor + 4
    }

    private static func text(
        _ value: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let string = value as NSString
        let bounds = string.boundingRect(
            with: CGSize(width: width, height: 2000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        string.draw(
            with: CGRect(x: x, y: y, width: width, height: ceil(bounds.height) + 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return y + ceil(bounds.height) + 4
    }
}

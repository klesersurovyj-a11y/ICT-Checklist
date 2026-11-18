//
//  TradeCardPDF.swift
//  ICT Checklist
//
//  Карточка одной сделки в PDF: уровни, риск, итог в R,
//  теги, классификация рынка и разбор.
//

import Foundation
import UIKit

enum TradeCardPDF {
    static func make(_ trade: Trade) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let day = Fmt.shortDay(trade.tradingDay).replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICT Checklist — сделка \(trade.symbol) \(day).pdf")

        do {
            try renderer.writePDF(to: url) { pdf in
                let writer = CardWriter(pdf: pdf)
                writer.head(trade)
                writer.summary(trade)
                writer.deal(trade)
                writer.review(trade)
            }
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Writer

private final class CardWriter {
    private let pdf: UIGraphicsPDFRendererContext
    private let left: CGFloat = 40
    private let right: CGFloat = 300
    private let width: CGFloat = 515
    private let bottom: CGFloat = 792
    private var y: CGFloat = 44

    init(pdf: UIGraphicsPDFRendererContext) {
        self.pdf = pdf
        pdf.beginPage()
    }

    // MARK: Header

    func head(_ trade: Trade) {
        line("ICT Checklist", font: .systemFont(ofSize: 10, weight: .semibold), color: .gray)
        y += 4
        line("\(trade.symbol) · \(trade.direction.rawValue)", font: .systemFont(ofSize: 28, weight: .bold), color: .black)
        y += 2
        line(dateLine(trade), font: .systemFont(ofSize: 11), color: .gray)
        y += 14
    }

    func summary(_ trade: Trade) {
        line("Итог", font: .systemFont(ofSize: 10), color: .gray)
        y += 4

        let rText = trade.result == .open ? "Открыта" : Fmt.r(trade.actualR)
        let tint: UIColor = trade.result == .open
            ? .darkGray
            : (trade.actualR > 0.05 ? .systemGreen : (trade.actualR < -0.05 ? .systemRed : .darkGray))

        line(rText, font: .systemFont(ofSize: 40, weight: .bold), color: tint)
        y += 2

        let status = trade.result == .open ? "Сделка открыта" : "Результат \(trade.result.rawValue)"
        let risk = "Риск \(Fmt.money(trade.riskUSD))   ·   план RR \(Fmt.rr(trade.plannedRR))"
        line("\(status)   ·   \(risk)", font: .systemFont(ofSize: 11.5, weight: .medium), color: .darkGray)
        y += 8

        stroke()
        y += 16
    }

    // MARK: Deal

    func deal(_ trade: Trade) {
        heading("Сделка")

        pair(
            ("Цена входа", Fmt.price(trade.entry)),
            ("Стоп", Fmt.price(trade.currentStop))
        )
        pair(
            ("Тейк", Fmt.price(trade.takeProfit)),
            ("План RR", Fmt.rr(trade.plannedRR))
        )
        pair(
            ("Риск", Fmt.money(trade.riskUSD)),
            ("Итог", trade.result == .open ? "—" : Fmt.r(trade.actualR))
        )
        pair(
            ("Дата входа", entryLine(trade)),
            ("Закрыта", closedLine(trade))
        )

        y += 6

        let classification = [trade.structure?.rawValue, trade.poiType?.rawValue, trade.marketSession.rawValue]
            .compactMap { $0 }
            .joined(separator: " · ")
        field("Классификация рынка", classification.isEmpty ? "—" : classification)
        field("Теги", trade.tags.isEmpty ? "—" : trade.tags.joined(separator: ", "))

        y += 8
    }

    // MARK: Review

    func review(_ trade: Trade) {
        if let review = trade.review, review.isFilled {
            heading("Разбор")
            field("Соблюдение алгоритма", review.adherence.rawValue)
            text(review.entryReason, title: "Причина входа")
            text(review.marketContext, title: "Рыночный контекст")
            text(review.resultReason, title: "Причина результата")
        }

        let note = trade.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            heading("Заметка")
            paragraph(note)
        }
    }

    // MARK: Pieces

    private func heading(_ text: String) {
        ensure(30)
        line(text, font: .systemFont(ofSize: 16, weight: .bold), color: .black)
        y += 8
    }

    private func text(_ value: String, title: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ensure(40)
        line(title, font: .systemFont(ofSize: 10), color: .gray)
        y += 2
        paragraph(trimmed)
        y += 8
    }

    private func field(_ title: String, _ value: String) {
        ensure(30)
        line(title, font: .systemFont(ofSize: 10), color: .gray)
        y += 2
        line(value, font: .systemFont(ofSize: 12.5, weight: .semibold), color: .black)
        y += 8
    }

    private func pair(
        _ leftItem: (title: String, value: String),
        _ rightItem: (title: String, value: String)
    ) {
        ensure(34)

        let titleFont = UIFont.systemFont(ofSize: 10)
        let valueFont = UIFont.systemFont(ofSize: 12.5, weight: .semibold)

        draw(leftItem.title, font: titleFont, color: .gray, x: left, at: y)
        draw(rightItem.title, font: titleFont, color: .gray, x: right, at: y)

        let valueTop = y + titleFont.lineHeight + 2
        draw(leftItem.value, font: valueFont, color: .black, x: left, at: valueTop)
        draw(rightItem.value, font: valueFont, color: .black, x: right, at: valueTop)

        y = valueTop + valueFont.lineHeight + 10
    }

    private func ensure(_ space: CGFloat) {
        guard y + space > bottom else { return }
        pdf.beginPage()
        y = 44
    }

    private func stroke() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: left, y: y))
        context.addLine(to: CGPoint(x: left + width, y: y))
        context.strokePath()
    }

    @discardableResult
    private func line(
        _ value: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat? = nil
    ) -> CGFloat {
        draw(value, font: font, color: color, x: x ?? left, at: y)
        y += font.lineHeight + 2
        return y
    }

    private func draw(
        _ value: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        at top: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(
            x: x,
            y: top,
            width: max(width - (x - left), 100),
            height: font.lineHeight + 2
        )
        (value as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func paragraph(_ value: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5),
            .foregroundColor: UIColor(white: 0.15, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let bounding = (value as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let height = ceil(bounding.height)
        ensure(height + 8)
        (value as NSString).draw(
            with: CGRect(x: left, y: y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        y += height
    }

    // MARK: Text helpers

    private func dateLine(_ trade: Trade) -> String {
        let day = Fmt.day(trade.tradingDay)
        let direction = trade.direction.rawValue
        return "\(day)   ·   \(direction)   ·   \(trade.symbol)"
    }

    private func entryLine(_ trade: Trade) -> String {
        "\(Fmt.shortDay(trade.entryDate)), \(Fmt.time(trade.entryDate))"
    }

    private func closedLine(_ trade: Trade) -> String {
        guard let closedAt = trade.closedAt else { return "—" }
        return "\(Fmt.shortDay(closedAt)), \(Fmt.time(closedAt))"
    }
}

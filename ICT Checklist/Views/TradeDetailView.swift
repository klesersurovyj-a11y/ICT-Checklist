//
//  TradeDetailView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import PhotosUI

struct TradeDetailView: View {
    let trade: Trade
    let usedTags: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showClose = false
    @State private var showTags = false
    @State private var showGallery = false
    @State private var showCycle = false
    @State private var pickedItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                    header
                    pricesCard
                    tagsCard
                    shotsSection
                    noteCard

                    if trade.result == .open {
                        PrimaryButton(title: "Закрыть сделку") {
                            showClose = true
                            Haptics.tap()
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showClose) {
            TradeCloseSheet(trade: trade, usedTags: usedTags)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showTags) {
            TradeTagsSheet(trade: trade, usedTags: usedTags)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .fullScreenCover(isPresented: $showGallery) {
            ScreenshotsGallery(trade: trade)
        }
        .fullScreenCover(isPresented: $showCycle) {
            if let cycle = trade.cycle {
                TradeCycleSheet(cycle: cycle)
            }
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShots(items) }
        }
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Сделка")

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(trade.symbol)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                directionBadge

                Spacer(minLength: 6)

                Text(resultRText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(resultRTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        "\(Fmt.shortDay(trade.tradingDay)) · \(Fmt.time(trade.entryDate)) · ступень \(trade.ladderStepIndex + 1) · риск \(Fmt.money(trade.riskUSD))"
    }

    private var resultRText: String {
        trade.result == .open ? "—" : Fmt.r(trade.actualR)
    }

    private var resultRTint: Color {
        switch trade.result {
        case .open: return Theme.textSecondary
        default: return rColor(trade.actualR)
        }
    }

    private var directionBadge: some View {
        Text(trade.direction.rawValue)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
            )
    }

    // MARK: - Prices

    private var pricesCard: some View {
        VStack(spacing: 0) {
            priceRow("Entry", value: Fmt.price(trade.entry))

            Divider()
                .overlay(Color.white.opacity(0.06))

            slRow

            Divider()
                .overlay(Color.white.opacity(0.06))

            priceRow("TP", value: Fmt.price(trade.takeProfit))

            Divider()
                .overlay(Color.white.opacity(0.06))

            HStack(spacing: 8) {
                pill("RR \(String(format: "%.1f", trade.plannedRR))")
                resultPill
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: 22)
    }

    private func priceRow(_ title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    private var slRow: some View {
        HStack(spacing: 8) {
            Text("SL")
                .font(.system(size: 17))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 62, alignment: .leading)

            Text(Fmt.price(trade.originalStop))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)

            if trade.isBE {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)

                Text("BE")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Text(Fmt.price(trade.currentStop))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var resultPill: some View {
        let tint: Color
        switch trade.result {
        case .tp: tint = Theme.green
        case .sl: tint = Theme.red
        case .be: tint = Theme.orange
        case .open: tint = Theme.accent
        }

        return Text(trade.result == .open ? "Открыта" : trade.result.rawValue)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.75)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Tags

    private var tagsCard: some View {
        Button {
            showTags = true
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(trade.tags.isEmpty ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(Theme.accent))
                        .frame(width: 30, height: 30)
                    Image(systemName: "tag.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                if trade.tags.isEmpty {
                    Text("Метки")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(Array(trade.tags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    if trade.tags.count > 2 {
                        Text("+\(trade.tags.count - 2)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Screenshots

    private var shotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trade.shots.isEmpty ? "Скриншоты" : "Скриншоты (\(trade.shots.count))")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(trade.sortedShots) { shot in
                        Button {
                            showGallery = true
                            Haptics.tap()
                        } label: {
                            ShotThumbnail(shot: shot, size: 74)
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(
                        selection: $pickedItems,
                        maxSelectionCount: 8,
                        matching: .images
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.14),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 74, height: 74)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func importShots(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                images.append(data)
            }
        }
        guard !images.isEmpty else {
            pickedItems = []
            return
        }
        for data in images {
            let shot = TradeShot(imageData: data)
            context.insert(shot)
            trade.shots.append(shot)
        }
        try? context.save()
        pickedItems = []
        Haptics.success()
    }

    // MARK: - Note and cycle

    @ViewBuilder
    private var noteCard: some View {
        let note = trade.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let cycle = trade.cycle

        if !note.isEmpty || cycle != nil {
            VStack(alignment: .leading, spacing: 0) {
                if !note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметка")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(note)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                }

                if !note.isEmpty && cycle != nil {
                    Divider()
                        .overlay(Theme.hairline)
                }

                if cycle != nil {
                    Button {
                        showCycle = true
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.16))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }

                            Text("Цикл дня")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .glassCard(cornerRadius: 22)
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Day cycle sheet

private struct TradeCycleSheet: View {
    let cycle: TradingCycle

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Цикл дня")
                            Text(Fmt.day(cycle.day))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Button("Закрыть") {
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }

                    DayResultView(cycle: cycle)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}

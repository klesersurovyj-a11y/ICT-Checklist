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

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @ObservedObject private var prices = PriceBook.shared

    @State private var showClose = false
    @State private var showTags = false
    @State private var showClassification = false
    @State private var showReplay = false
    @State private var showGallery = false
    @State private var showCycle = false
    @State private var showDuplicate = false
    @State private var pickedItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                        .reveal(.drop)
                    header
                        .reveal(.blur, 1)
                    replayCard
                        .reveal(.rise, 2)
                    accountCard
                        .reveal(.rise, 2)
                    pricesCard
                        .reveal(.rise, 3)
                    liveCard
                        .reveal(.rise, 4)
                    tagsCard
                        .reveal(.rise, 5)
                    classificationCard
                        .reveal(.rise, 6)
                    shotsSection
                        .reveal(.rise, 8)
                    noteCard
                        .reveal(.rise, 9)

                    duplicateButton
                        .reveal(.rise, 10)

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
        .sheet(isPresented: $showClassification) {
            TradeClassificationSheet(trade: trade)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .fullScreenCover(isPresented: $showReplay) {
            TradeReplayView(trade: trade)
        }
        .fullScreenCover(isPresented: $showGallery) {
            ScreenshotsGallery(trade: trade)
        }
        .fullScreenCover(isPresented: $showCycle) {
            if let cycle = trade.cycle {
                TradeCycleSheet(cycle: cycle)
            }
        }
        .fullScreenCover(isPresented: $showDuplicate) {
            NewTradeView(prefillTrade: trade)
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShots(items) }
        }
        .task(id: trade.symbol) {
            guard trade.result == .open else { return }
            await prices.refresh(symbols: [trade.symbol.uppercased()])
        }
    }

    // MARK: - Live market

    @ViewBuilder
    private var liveCard: some View {
        if trade.result == .open {
            let quote = prices.quote(for: trade.symbol)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(quote == nil ? Theme.textTertiary : Theme.accent)
                        .frame(width: 5, height: 5)

                    Text(quote == nil ? "Цена рынка" : "Цена рынка \(Fmt.price(quote!.price))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(quote == nil ? Theme.textSecondary : .white)

                    Spacer(minLength: 8)

                    if let quote {
                        Text(Fmt.time(quote.updatedAt))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Button {
                        Task {
                            await prices.refresh(symbols: [trade.symbol.uppercased()], force: true)
                        }
                        Haptics.tap()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .glassCircle()
                    }
                    .buttonStyle(.plain)
                }

                if let quote, let distances = PriceMonitor.distances(trade, price: quote.price) {
                    HStack(spacing: 6) {
                        distancePill("До TP", value: distances.toTargetR, tint: Theme.green)
                        distancePill("До SL", value: distances.toStopR, tint: Theme.red)
                        distancePill("До BE", value: distances.toBreakEvenR, tint: Theme.textSecondary)
                    }
                } else {
                    Text(
                        prices.hasKey
                            ? "Нажмите ↻, чтобы получить цену."
                            : "Добавьте ключ TWELVE_DATA_API_KEY в настройках ключей приложения."
                    )
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
            .animation(.easeInOut(duration: 0.25), value: quote?.price)
        }
    }

    private func distancePill(_ title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Text(String(format: "%.1fR", value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .glassCircle()
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                directionBadge

                Spacer(minLength: 6)

                Text(resultRText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(resultRTint)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(subtitle)
                .font(.system(size: 13.5))
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

    private var duplicateButton: some View {
        Button {
            showDuplicate = true
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 13, weight: .semibold))
                Text("Дублировать")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Account
    private var accountCard: some View {
        Menu {
            Button("Без счёта") {
                setAccount(nil)
            }
            if !accounts.isEmpty {
                Divider()
                ForEach(accounts) { item in
                    Button("\(item.name) · \(item.type.rawValue)") {
                        setAccount(item)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: "building.columns")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Счёт")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(trade.account.map { "\($0.name) · \($0.type.rawValue)" } ?? "Без счёта")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(trade.account == nil ? Theme.textSecondary : .white)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
    }

    private func setAccount(_ account: TradingAccount?) {
        trade.account = account
        try? context.save()
        Haptics.select()
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

    // MARK: - Market behavior

    private var classificationCard: some View {
        Button {
            showClassification = true
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Поведение рынка")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(classificationLine)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

    private var classificationLine: String {
        var parts: [String] = []
        if let structure = trade.structure {
            parts.append(structure.rawValue)
        }
        if let poi = trade.poiType {
            parts.append(poi.rawValue)
        }
        parts.append(trade.marketSession.rawValue)
        return parts.joined(separator: " · ")
    }

    // MARK: - Replay

    private var replayCard: some View {
        Button {
            showReplay = true
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade Replay & Review")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(replayLine)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

    private var replayLine: String {
        var parts: [String] = []
        if trade.shot(with: .beforeEntry) != nil {
            parts.append("до входа")
        }
        if trade.shot(with: .afterClose) != nil {
            parts.append("после закрытия")
        }
        if let review = trade.review, review.adherence != .unknown {
            parts.append(review.adherence.rawValue.lowercased())
        }
        guard !parts.isEmpty else {
            return "Скриншоты, причина, контекст, соблюдение"
        }
        return parts.joined(separator: " · ")
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

// MARK: - Classification sheet

struct TradeClassificationSheet: View {
    let trade: Trade

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                structureSection
                poiSection
                InfoHint(
                    text: "Метка нужна разделу Market Behavior Analyzer. «Авто» берёт структуру и POI из цикла дня: SOF → Reversal, вход против недельного потока → Correction, рабочий Key Level → тип POI."
                )
            }
            .padding(22)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Поведение рынка")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(trade.symbol) · \(Fmt.shortDay(trade.tradingDay)) · \(trade.marketSession.rawValue)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            Button("Готово") {
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.blue)
        }
    }

    // MARK: - Structure

    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Структура рынка")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(
                        title: "Авто",
                        isSelected: trade.structureRaw.isEmpty,
                        tint: Theme.accent
                    ) {
                        setStructure(nil)
                    }

                    ForEach(MarketStructure.allCases) { value in
                        Chip(
                            title: value.rawValue,
                            isSelected: trade.structureRaw == value.rawValue,
                            tint: Theme.accent
                        ) {
                            setStructure(value)
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Text(structureHint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var structureHint: String {
        guard let derived = MarketBehavior.derivedStructure(for: trade) else {
            return "У сделки нет цикла дня — выберите структуру вручную."
        }
        return "Из цикла дня: \(derived.rawValue)"
    }

    private func setStructure(_ value: MarketStructure?) {
        trade.structureRaw = value?.rawValue ?? ""
        try? context.save()
        Haptics.select()
    }

    // MARK: - POI

    private var poiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "POI")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(
                        title: "Авто",
                        isSelected: trade.poiRaw.isEmpty,
                        tint: Theme.accent
                    ) {
                        setPOI(nil)
                    }

                    ForEach(POIType.allCases) { value in
                        Chip(
                            title: value.rawValue,
                            isSelected: trade.poiRaw == value.rawValue,
                            tint: Theme.accent
                        ) {
                            setPOI(value)
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Text(poiHint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var poiHint: String {
        guard let derived = MarketBehavior.derivedPOI(for: trade) else {
            return "У сделки нет цикла дня — выберите POI вручную."
        }
        return "Из цикла дня: \(derived.rawValue)"
    }

    private func setPOI(_ value: POIType?) {
        trade.poiRaw = value?.rawValue ?? ""
        try? context.save()
        Haptics.select()
    }
}

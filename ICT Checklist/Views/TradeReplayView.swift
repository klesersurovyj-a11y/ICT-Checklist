//
//  TradeReplayView.swift
//  ICT Checklist
//
//  Trade Replay & Review: возврат к закрытой сделке, скриншоты до входа
//  и после закрытия, причина входа, рыночный контекст, соблюдение
//  алгоритма и причина результата.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TradeReplayView: View {
    let trade: Trade

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var review: TradeReview?

    var body: some View {
        ZStack {
            AppBackground()

            if let review {
                TradeReplayContent(trade: trade, review: review) {
                    dismiss()
                }
            }
        }
        .task {
            guard review == nil else { return }
            review = loadOrCreate()
        }
    }

    private func loadOrCreate() -> TradeReview {
        if let existing = trade.review {
            return existing
        }
        let created = TradeReview(trade: trade)
        context.insert(created)
        trade.review = created
        try? context.save()
        return created
    }
}

// MARK: - Content

private struct TradeReplayContent: View {
    let trade: Trade
    @Bindable var review: TradeReview
    var onClose: () -> Void

    @Environment(\.modelContext) private var context

    @State private var beforeItems: [PhotosPickerItem] = []
    @State private var afterItems: [PhotosPickerItem] = []
    @State private var previewShot: TradeShot?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                backButton
                    .reveal(.slideLeft)
                header
                    .reveal(.drop)
                summaryCard
                    .reveal(.zoom, 1)
                shotsCard
                    .reveal(.rise, 2)
                entryReasonCard
                    .reveal(.rise, 3)
                contextCard
                    .reveal(.rise, 4)
                adherenceCard
                    .reveal(.rise, 5)
                resultReasonCard
                    .reveal(.rise, 6)

                if hasChecklistContext {
                    checklistContextCard
                        .reveal(.rise, 7)
                }

                footer
                    .reveal(.blur, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(item: $previewShot) { shot in
            ReplayShotSheet(shot: shot)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .onChange(of: beforeItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShot(items, role: .beforeEntry) }
        }
        .onChange(of: afterItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importShot(items, role: .afterClose) }
        }
        .onDisappear { try? context.save() }
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            onClose()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Назад")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Replay & Review")
            ScreenTitle(text: "Разбор сделки")
            Text("\(trade.symbol) · \(Fmt.day(trade.tradingDay)) · \(trade.marketSession.rawValue)")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(trade.direction.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                    )

                Text(trade.result == .open ? "Открыта" : trade.result.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))

                Spacer(minLength: 6)

                Text(Fmt.r(trade.actualR))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rTint(trade.actualR))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let structure = trade.structure {
                        miniPill(structure.rawValue)
                    }
                    if let poi = trade.poiType {
                        miniPill(poi.rawValue)
                    }
                    miniPill(trade.marketSession.rawValue)
                }
            }

            HStack(spacing: 10) {
                MetricTile(title: "Дата", value: Fmt.shortDay(trade.tradingDay))
                MetricTile(title: "Entry", value: Fmt.price(trade.entry))
                MetricTile(title: "SL", value: Fmt.price(trade.originalStop), tint: Theme.red)
                MetricTile(title: "TP", value: Fmt.price(trade.takeProfit), tint: Theme.green)
            }

            if trade.result == .open {
                InfoHint(
                    text: "Сделка ещё открыта — причину результата можно будет заполнить после закрытия.",
                    tint: Theme.textSecondary,
                    icon: "clock"
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func miniPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Screenshots

    private var shotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Скриншоты")

            HStack(alignment: .top, spacing: 10) {
                shotSlot(
                    title: ShotRole.beforeEntry.title,
                    shot: trade.shot(with: .beforeEntry),
                    items: $beforeItems
                )
                shotSlot(
                    title: ShotRole.afterClose.title,
                    shot: trade.shot(with: .afterClose),
                    items: $afterItems
                )
            }

            Text("Скриншоты хранятся в базе и синхронизируются через iCloud. Уже добавленные снимки можно разметить как «до входа» или «после закрытия» в галерее сделки.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func shotSlot(
        title: String,
        shot: TradeShot?,
        items: Binding<[PhotosPickerItem]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let shot {
                Button {
                    previewShot = shot
                } label: {
                    ReplayShotImage(shot: shot)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Открыть") { previewShot = shot }
                    Button("Удалить", role: .destructive) { delete(shot) }
                }

                PhotosPicker(
                    selection: items,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    Text("Заменить")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
            } else {
                PhotosPicker(
                    selection: items,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(0.14),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                        VStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                            Text("Добавить")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete(_ shot: TradeShot) {
        ScreenshotStore.delete(shot.fileName)
        trade.shots.removeAll { $0 === shot }
        context.delete(shot)
        try? context.save()
        Haptics.tap()
    }

    private func importShot(_ items: [PhotosPickerItem], role: ShotRole) async {
        guard let item = items.first,
              let data = try? await item.loadTransferable(type: Data.self) else {
            reset(role)
            return
        }

        if let existing = trade.shot(with: role) {
            ScreenshotStore.delete(existing.fileName)
            existing.imageData = data
            existing.role = role
            existing.createdAt = .now
        } else {
            let shot = TradeShot(imageData: data, role: role)
            context.insert(shot)
            trade.shots.append(shot)
        }

        try? context.save()
        reset(role)
        Haptics.success()
    }

    private func reset(_ role: ShotRole) {
        switch role {
        case .beforeEntry:
            beforeItems = []
        case .afterClose:
            afterItems = []
        case .general:
            break
        }
    }

    // MARK: - Reasons

    private var entryReasonCard: some View {
        reasonCard(
            title: "Причина входа",
            placeholder: "Почему был вход: сетап, уровень, подтверждения…",
            text: $review.entryReason
        )
    }

    private var contextCard: some View {
        reasonCard(
            title: "Рыночный контекст",
            placeholder: "Trend / Reversal / Correction, сессия, новости, структура…",
            text: $review.marketContext
        )
    }

    private var resultReasonCard: some View {
        reasonCard(
            title: "Причина результата",
            placeholder: "Что дало результат: объём, реакция, управление, ошибка…",
            text: $review.resultReason
        )
    }

    private func reasonCard(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            GlassNoteField(
                placeholder: placeholder,
                text: text,
                limit: 500,
                lines: 3...7,
                minHeight: 84
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Adherence

    private var adherenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "Соблюдение алгоритма")
                Spacer(minLength: 6)
                Text(review.adherence.rawValue)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(adherenceTint(review.adherence))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(adherenceTint(review.adherence).opacity(0.14)))
            }

            GlassSegmented(
                options: AlgorithmAdherence.allCases,
                selection: Binding(
                    get: { review.adherence },
                    set: { value in
                        review.adherence = value
                        Haptics.select()
                    }
                ),
                label: { $0.shortTitle },
                tint: { adherenceTint($0) }
            )

            Text(review.adherence.subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let plan = trade.plan {
                InfoHint(
                    text: "Чек-лист дня: \(plan.checkedCount)/\(PlanCheck.allCases.count)",
                    tint: plan.isChecklistComplete ? Theme.green : Theme.textSecondary,
                    icon: plan.isChecklistComplete ? "checkmark.seal" : "checklist"
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func adherenceTint(_ value: AlgorithmAdherence) -> Color {
        switch value {
        case .unknown:
            return Theme.textSecondary
        case .followed:
            return Theme.green
        case .partial:
            return Theme.textPrimary
        case .broken:
            return Theme.red
        }
    }

    // MARK: - Checklist context

    private var hasChecklistContext: Bool {
        trade.cycle != nil || trade.plan != nil
    }

    private var checklistContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Контекст из чек-листа")
            SummaryTable(items: contextItems)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var contextItems: [SummaryItem] {
        var items: [SummaryItem] = []

        if let cycle = trade.cycle {
            items.append(SummaryItem(title: "Направление", value: cycle.direction.rawValue))
            items.append(SummaryItem(title: "Поток", value: cycle.trendType.rawValue))
            if let zone = cycle.zone {
                items.append(SummaryItem(title: "Зона", value: zone.rawValue))
            }
            if let high = cycle.drHigh, let low = cycle.drLow, high > low {
                items.append(SummaryItem(title: "DR", value: "\(Fmt.price(low))–\(Fmt.price(high))"))
            }
            if let pointA = cycle.pointAPrice {
                items.append(SummaryItem(title: "Point A", value: Fmt.price(pointA)))
            }
            if let pointB = cycle.pointBPrice {
                items.append(SummaryItem(title: "Point B", value: Fmt.price(pointB)))
            }
            if let rr = cycle.computedRR {
                items.append(SummaryItem(title: "RR", value: Fmt.rr(rr)))
            }
            items.append(
                SummaryItem(
                    title: "Подтверждения",
                    value: "\(cycle.confirmations.count)/\(ConfirmationKey.allCases.count)",
                    tint: cycle.confirmations.count >= 4 ? Theme.green : Theme.textPrimary
                )
            )
        }

        if let plan = trade.plan {
            items.append(
                SummaryItem(
                    title: "Чек-лист плана",
                    value: "\(plan.checkedCount)/\(PlanCheck.allCases.count)",
                    tint: plan.isChecklistComplete ? Theme.green : Theme.textPrimary
                )
            )
        }

        return items
    }

    // MARK: - Footer

    private var footer: some View {
        InfoHint(
            text: "Разбор сохраняется автоматически. Скриншоты «до входа» и «после закрытия» можно заменить в любой момент.",
            icon: "arrow.triangle.2.circlepath"
        )
        .padding(16)
        .glassCard(cornerRadius: 22)
    }
}

// MARK: - Shot views

private struct ReplayShotImage: View {
    let shot: TradeShot

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: shot.imageData?.count) {
            image = ScreenshotStore.image(for: shot)
        }
    }
}

private struct ReplayShotSheet: View {
    let shot: TradeShot

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(shot.role.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(Fmt.shortDay(shot.createdAt))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                }

                ShotImage(shot: shot, maxHeight: 640)
            }
            .padding(22)
        }
    }
}

private func rTint(_ value: Double) -> Color {
    if value > 0.05 { return Theme.green }
    if value < -0.05 { return Theme.red }
    return Theme.textSecondary
}

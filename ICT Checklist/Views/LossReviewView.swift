//
//  LossReviewView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct LossReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var trades: [Trade]
    @Query private var reviews: [LossReview]

    @State private var period: StatsPeriod = .all
    @State private var selectedTrade: Trade?

    // MARK: - Data

    private var lossTrades: [Trade] {
        trades
            .filter { $0.result == .sl }
            .filter { period.contains($0.closedAt ?? $0.tradingDay) }
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

    private var totalR: Double {
        lossTrades.reduce(0) { $0 + $1.actualR }
    }

    private var averageR: Double {
        lossTrades.isEmpty ? 0 : totalR / Double(lossTrades.count)
    }

    private var usedTags: [String] {
        Array(Set(trades.flatMap { $0.tags })).sorted()
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.slideLeft)

                    GlassSegmented(
                        options: StatsPeriod.allCases,
                        selection: $period,
                        label: { $0.rawValue },
                        tint: { _ in Theme.accent }
                    )
                    .reveal(.blur, 1)

                    if lossTrades.isEmpty {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        tiles
                            .reveal(.zoom, 2)
                        breakdownRow("По символам", groups: grouped(lossTrades, key: { $0.symbol }))
                        breakdownRow("По часам входа", groups: hourGroups(lossTrades))
                        if !tagGroups(lossTrades).isEmpty {
                            breakdownRow("По меткам", groups: tagGroups(lossTrades))
                        }

                        ForEach(lossTrades) { trade in
                            lossCard(trade)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .glassCircle()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Разбор SL")
                ScreenTitle(text: "Почему в минус")
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Summary

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("Сделок в минус", "\(lossTrades.count)", tint: Theme.textPrimary)
            tile("Суммарный R", Fmt.r(totalR), tint: Theme.red)
            tile("Средний R", Fmt.signed(averageR, digits: 2), tint: Theme.textSecondary)
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Breakdowns

    private func breakdownRow(_ title: String, groups: [(title: String, count: Int, totalR: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider().overlay(Theme.hairline)
                    }
                    HStack(spacing: 10) {
                        Text(group.title)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(group.count)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(Fmt.r(group.totalR))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rColor(group.totalR))
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                }
            }
            .padding(.horizontal, 14)
            .glassCard(cornerRadius: 18)
        }
    }

    private func grouped(_ items: [Trade], key: (Trade) -> String) -> [(title: String, count: Int, totalR: Double)] {
        var map: [String: [Trade]] = [:]
        for trade in items {
            map[key(trade), default: []].append(trade)
        }
        return map
            .map { name, list in
                (name, list.count, list.reduce(0) { $0 + $1.actualR })
            }
            .sorted { first, second in
                if first.1 != second.1 { return first.1 > second.1 }
                return first.2 < second.2
            }
    }

    private func hourGroups(_ items: [Trade]) -> [(title: String, count: Int, totalR: Double)] {
        grouped(items) { trade in
            let hour = Calendar.current.component(.hour, from: trade.entryDate)
            return String(format: "%02d:00", hour)
        }
    }

    private func tagGroups(_ items: [Trade]) -> [(title: String, count: Int, totalR: Double)] {
        var map: [String: [Trade]] = [:]
        for trade in items {
            for tag in Set(trade.tags) {
                map[tag, default: []].append(trade)
            }
        }
        return map
            .map { tag, list in
                (tag, list.count, list.reduce(0) { $0 + $1.actualR })
            }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Loss cards

    private func lossCard(_ trade: Trade) -> some View {
        let review = review(for: trade)

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedTrade = trade
                Haptics.tap()
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(trade.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(trade.direction.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        (trade.direction == .long ? Theme.green : Theme.red).opacity(0.9)
                                    )
                                )
                        }
                        Text("\(Fmt.shortDay(trade.tradingDay)) · ступень \(trade.ladderStepIndex + 1)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(Fmt.r(trade.actualR))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.red)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !entryElements(trade).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entryElements(trade), id: \.self) { element in
                            Text(element)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.lavender)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Theme.accent.opacity(0.14)))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ПОЧЕМУ ТАК ПРОИЗОШЛО")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)

                TextField("Что видел, что сделал и что произошло", text: noteBinding(trade), axis: .vertical)
                    .lineLimit(2...6)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }

            similarBlock(trade, review: review)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func entryElements(_ trade: Trade) -> [String] {
        var elements: [String] = []
        if let cycle = trade.cycle {
            if let zone = cycle.zone {
                elements.append(zone.rawValue)
            }
            elements.append(cycle.trendType.rawValue)
            let levelTypes = Array(Set(cycle.keyLevels.map { $0.type.rawValue })).sorted()
            if !levelTypes.isEmpty {
                elements.append("KL: " + levelTypes.joined(separator: ", "))
            }
            let confirmed = cycle.confirmations.count
            elements.append("Подтв. \(confirmed)/6")
        }
        for tag in trade.tags {
            if !elements.contains(tag) {
                elements.append(tag)
            }
        }
        return elements
    }

    private func similarBlock(_ trade: Trade, review: LossReview?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("СХОЖИЕ СДЕЛКИ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                Menu {
                    let candidates = attachCandidates(trade)
                    if candidates.isEmpty {
                        Text("Нет свободных сделок")
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                attach(candidate, to: trade)
                            } label: {
                                Text("\(Fmt.shortDay(candidate.tradingDay)) · \(candidate.symbol) · \(candidate.result.rawValue)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Прикрепить")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
            }

            let attached = review?.similar ?? []
            if attached.isEmpty {
                Text("Пока ничего не прикреплено")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(attached) { item in
                    HStack(spacing: 8) {
                        Text("\(Fmt.shortDay(item.tradingDay)) · \(item.symbol) · \(item.result.rawValue)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.result == .open ? "—" : Fmt.r(item.actualR))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(rColor(item.actualR))
                        Button {
                            detach(item, from: trade)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 20, height: 20)
                                .glassCircle()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func attachCandidates(_ trade: Trade) -> [Trade] {
        let attachedIDs = Set((review(for: trade)?.similar ?? []).map { $0.persistentModelID })
        return trades
            .filter { $0.result != .open }
            .filter { $0.persistentModelID != trade.persistentModelID }
            .filter { !attachedIDs.contains($0.persistentModelID) }
            .sorted { ($0.closedAt ?? $0.tradingDay) > ($1.closedAt ?? $1.tradingDay) }
    }

    // MARK: - Review storage

    private func review(for trade: Trade) -> LossReview? {
        reviews.first { $0.trade?.persistentModelID == trade.persistentModelID }
    }

    private func noteBinding(_ trade: Trade) -> Binding<String> {
        Binding(
            get: { review(for: trade)?.note ?? "" },
            set: { value in
                let item = ensureReview(trade)
                item.note = value
                item.updatedAt = .now
                try? context.save()
            }
        )
    }

    @discardableResult
    private func ensureReview(_ trade: Trade) -> LossReview {
        if let existing = review(for: trade) {
            return existing
        }
        let item = LossReview(trade: trade)
        context.insert(item)
        item.trade = trade
        try? context.save()
        return item
    }

    private func attach(_ candidate: Trade, to trade: Trade) {
        let item = ensureReview(trade)
        item.attach(candidate)
        try? context.save()
        Haptics.tap()
    }

    private func detach(_ candidate: Trade, from trade: Trade) {
        guard let item = review(for: trade) else { return }
        item.detach(candidate)
        try? context.save()
        Haptics.tap()
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Убыточных сделок нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Здесь появятся все сделки, закрытые по SL, с элементами входа и разбором причины.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}

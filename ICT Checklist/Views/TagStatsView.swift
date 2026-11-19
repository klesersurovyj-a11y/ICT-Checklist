//
//  TagStatsView.swift
//  ICT Checklist
//
//  «Теги»: какие признаки сделок приносят R.
//

import SwiftUI
import SwiftData

struct TagStatsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: EntryHeatPeriod = .days30
    @State private var selectedTag: String?
    @State private var sheet: TagTradesData?

    private var stats: [EntryTagStat] {
        TagStatsEngine.report(trades: trades, period: period)
    }

    private var usedTags: [String] {
        stats.map(\.title)
    }

    var body: some View {
        let snapshot = stats

        return ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    GlassSegmented(
                        options: EntryHeatPeriod.allCases,
                        selection: periodBinding,
                        label: { $0.rawValue }
                    )
                    .reveal(.blur, 1)

                    columnRow
                        .reveal(.rise, 2)

                    if snapshot.isEmpty {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        tagList(snapshot)
                            .reveal(.zoom, 2)
                    }

                    actionButton(snapshot)
                        .reveal(.rise, 3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $sheet) { data in
            TagTradesSheet(title: data.title, trades: data.trades, usedTags: usedTags)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Статистика")
                ScreenTitle(text: "Теги")
                Text("Какие признаки сделок приносят R")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

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
        }
    }

    private var periodBinding: Binding<EntryHeatPeriod> {
        Binding(
            get: { period },
            set: { value in
                period = value
                selectedTag = nil
                Haptics.select()
            }
        )
    }

    private var columnRow: some View {
        HStack(spacing: 8) {
            Text("Тег")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("R")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - List

    private func tagList(_ stats: [EntryTagStat]) -> some View {
        let maxAbs = max(stats.map { abs($0.totalR) }.max() ?? 0, 0.1)

        return VStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                Button {
                    selectedTag = stat.title
                    sheet = TagTradesData(title: stat.title, trades: stat.trades)
                    Haptics.tap()
                } label: {
                    row(stat, maxAbs: maxAbs)
                }
                .buttonStyle(.plain)

                if index < stats.count - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                        .padding(.leading, 18)
                }
            }
        }
        .padding(.horizontal, 10)
        .glassCard(cornerRadius: 22)
    }

    private func row(_ stat: EntryTagStat, maxAbs: Double) -> some View {
        let tint = tintFor(stat.totalR)
        let ratio = min(abs(stat.totalR) / maxAbs, 1)
        let isSelected = selectedTag == stat.title

        return HStack(spacing: 12) {
            Capsule()
                .fill(tint)
                .frame(width: 3, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(stat.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(Fmt.deals(stat.count)) · \(stat.winRate)% winrate · ср. \(Fmt.r(stat.averageR))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 6)

            Text(Fmt.r(stat.totalR))
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(height: max(6, 38 * ratio))
            }
            .frame(width: 3, height: 38)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.05 : 0))
        )
        .contentShape(Rectangle())
    }

    private func tintFor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Empty and action

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Тегов пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Добавьте теги к сделкам — и здесь появится, какие признаки приносят R, а какие отдают.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    private func actionButton(_ stats: [EntryTagStat]) -> some View {
        Button {
            guard let selectedTag,
                  let stat = stats.first(where: { $0.title == selectedTag }) else {
                Haptics.warning()
                return
            }
            sheet = TagTradesData(title: stat.title, trades: stat.trades)
            Haptics.tap()
        } label: {
            Text("Показать сделки тега")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(selectedTag == nil || stats.isEmpty)
        .opacity(selectedTag == nil || stats.isEmpty ? 0.45 : 1)
        .padding(.top, 4)
    }
}

// MARK: - Sheet data

private struct TagTradesData: Identifiable {
    let id = UUID()
    let title: String
    let trades: [Trade]
}

// MARK: - Trades sheet

private struct TagTradesSheet: View {
    let title: String
    let trades: [Trade]
    let usedTags: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTrade: Trade?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    list
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, usedTags: usedTags)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Тег")
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(Fmt.deals(trades.count)) · \(Fmt.r(trades.reduce(0) { $0 + $1.actualR }))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var list: some View {
        if trades.isEmpty {
            Text("У этого тега пока нет закрытых сделок.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 20)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                    Button {
                        selectedTrade = trade
                        Haptics.tap()
                    } label: {
                        row(trade)
                    }
                    .buttonStyle(.plain)

                    if index < trades.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    private func row(_ trade: Trade) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.shortDay(trade.tradingDay))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Text(trade.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(trade.result.rawValue)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(resultTint(trade.result))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(resultTint(trade.result).opacity(0.16)))

            Spacer(minLength: 6)

            Text(Fmt.r(trade.actualR))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rColor(trade.actualR))

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func resultTint(_ result: TradeResult) -> Color {
        switch result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return Theme.textSecondary
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

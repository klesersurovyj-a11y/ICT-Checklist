//
//  BreakdownDetailView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct BreakdownTarget: Identifiable {
    let id: String
    let title: String
    let kind: BreakdownKind
}

struct BreakdownDetailView: View {
    let target: BreakdownTarget
    @Binding var period: StatsPeriod

    @Query private var trades: [Trade]

    @Environment(\.dismiss) private var dismiss

    private var groupTrades: [Trade] {
        StatsEngine.detailTrades(trades, period: period, kind: target.kind)
    }

    private var count: Int { groupTrades.count }

    private var wins: Int {
        groupTrades.filter { $0.actualR > 0.05 }.count
    }

    private var winRate: Double {
        count == 0 ? 0 : Double(wins) / Double(count)
    }

    private var totalR: Double {
        groupTrades.reduce(0) { $0 + $1.actualR }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)
                    tiles
                        .reveal(.zoom, 1)

                    if groupTrades.isEmpty {
                        emptyCard
                    } else {
                        Text("Сделки")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        LazyVStack(spacing: 12) {
                            ForEach(groupTrades) { trade in
                                card(trade)
                            }
                        }
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Разбивка")
                    ScreenTitle(text: target.title)
                }
                Spacer(minLength: 8)
                periodMenu
            }

            (
                Text(Fmt.deals(count))
                + Text(" · \(Int((winRate * 100).rounded()))% · ")
                + Text(Fmt.r(totalR)).foregroundColor(rColor(totalR))
            )
            .font(.system(size: 15))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodMenu: some View {
        Menu {
            ForEach(StatsPeriod.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        period = item
                    }
                    Haptics.select()
                } label: {
                    if item == period {
                        Label(item.rawValue, systemImage: "checkmark")
                    } else {
                        Text(item.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(period.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    // MARK: - Tiles

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("Сделок", "\(count)", tint: .white)
            tile("Win rate", "\(Int((winRate * 100).rounded()))%", tint: Theme.green)
            tile("Суммарный R", Fmt.r(totalR), tint: rColor(totalR))
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Cards

    private func card(_ trade: Trade) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Fmt.shortDay(trade.tradingDay))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 10) {
                Text(trade.direction.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill((trade.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                    )
                Spacer(minLength: 4)
                Text(Fmt.r(trade.actualR))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(rColor(trade.actualR))
            }

            Text(targetLine(trade))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func targetLine(_ trade: Trade) -> String {
        let entry = Fmt.price(trade.entry)
        switch trade.result {
        case .tp:
            return "entry \(entry) → TP \(Fmt.price(trade.takeProfit))"
        case .sl:
            return "entry \(entry) → SL \(Fmt.price(trade.currentStop))"
        case .be:
            return "entry \(entry) → BE \(Fmt.price(trade.entry))"
        case .open:
            return "entry \(entry) → открыта"
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нет сделок в этой разбивке")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("За выбранный период в этой группе нет закрытых сделок. Смените период в меню сверху.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var footer: some View {
        Text("Фильтр периода совпадает со «Статистикой»")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

//
//  MarketBehaviorView.swift
//  ICT Checklist
//
//  Market Behavior Analyzer: поведение торговой системы в разной
//  рыночной структуре, по сессиям, дням недели, инструментам и POI.
//

import SwiftUI
import SwiftData

struct MarketBehaviorView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: BehaviorPeriod = .all
    @State private var bucket: BehaviorBucketSelection?
    @State private var showAssistant = false

    private var report: BehaviorReport {
        MarketBehaviorEngine.report(trades: trades, period: period)
    }

    private var bestStructure: BehaviorGroup? {
        MarketBehaviorEngine.bestGroup(report.dimensions.first { $0.id == "structure" })
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

                    GlassSegmented(
                        options: BehaviorPeriod.allCases,
                        selection: $period,
                        label: { $0.rawValue },
                        tint: { _ in Theme.blue }
                    )
                    .reveal(.blur, 1)

                    Text(period.caption)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textTertiary)

                    if report.closedCount == 0 {
                        emptyCard
                    } else {
                        tilesGrid
                            .reveal(.zoom, 2)
                        verdictCard
                            .reveal(.rise, 3)

                        ForEach(Array(report.dimensions.enumerated()), id: \.element.id) { index, dimension in
                            dimensionCard(dimension)
                                .reveal(.rise, index + 4)
                        }

                        assistantCard
                            .reveal(.rise, 9)
                        hintCard
                            .reveal(.blur, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(Theme.snappy, value: period)
            }
        }
        .sheet(item: $bucket) { selection in
            BehaviorBucketSheet(selection: selection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: assistantPrompt)
        }
    }

    private var assistantPrompt: String {
        "Разбери поведение моей торговой системы по базе сделок: где она зарабатывает, где теряет и что исправить в первую очередь. Разбивка:\n"
            + MarketBehaviorEngine.promptSummary(report, period: period)
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
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
            SectionLabel(text: "Market Behavior")
            ScreenTitle(text: "Поведение системы")
            Text("Как торговый план работает в разной рыночной структуре: Trend, Reversal, Correction, сессии, дни недели, инструменты и POI.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tiles

    private var tilesGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricTile(title: "Сделок", value: "\(report.closedCount)")
                MetricTile(
                    title: "Win rate",
                    value: MarketBehaviorEngine.percentText(report.winRate),
                    tint: report.winRate >= 0.5 ? Theme.green : Theme.textPrimary
                )
                MetricTile(title: "Суммарно", value: Fmt.r(report.totalR), tint: rTint(report.totalR))
            }
            HStack(spacing: 10) {
                MetricTile(
                    title: "Средний R",
                    value: MarketBehaviorEngine.averageText(report.averageR),
                    tint: rTint(report.averageR)
                )
                MetricTile(
                    title: "Профит-фактор",
                    value: MarketBehaviorEngine.profitFactorText(report.profitFactor)
                )
                MetricTile(title: "Лучшая структура", value: bestStructure?.title ?? "—")
            }
        }
    }

    // MARK: - Verdict

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "Что показывает база")
                Spacer()
            }

            ForEach(report.insights) { insight in
                insightRow(insight)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func insightRow(_ insight: BehaviorInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toneIcon(insight.tone))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(toneColor(insight.tone))
                .frame(width: 26, height: 26)
                .background(Circle().fill(toneColor(insight.tone).opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Dimensions

    private func dimensionCard(_ dimension: BehaviorDimension) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dimension.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dimension.caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            if dimension.filledGroups.isEmpty {
                Text("Нет данных за выбранный период")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(dimension.filledGroups) { group in
                    groupRow(group, maxMagnitude: dimension.maxMagnitude, dimensionTitle: dimension.title)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func groupRow(
        _ group: BehaviorGroup,
        maxMagnitude: Double,
        dimensionTitle: String
    ) -> some View {
        Button {
            bucket = BehaviorBucketSelection(
                id: group.id,
                title: group.title,
                subtitle: group.subtitle ?? dimensionTitle,
                trades: group.trades
            )
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(group.isUnlabeled ? Theme.textSecondary : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("\(group.count) сд.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)

                    Spacer(minLength: 6)

                    Text(MarketBehaviorEngine.percentText(group.winRate))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)

                    Text(Fmt.r(group.totalR))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rTint(group.totalR))
                        .frame(minWidth: 58, alignment: .trailing)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                        Capsule()
                            .fill(rTint(group.totalR).opacity(group.isUnlabeled ? 0.25 : 0.6))
                            .frame(width: barWidth(
                                value: group.totalR,
                                maxMagnitude: maxMagnitude,
                                available: proxy.size.width
                            ))
                    }
                }
                .frame(height: 5)

                if let subtitle = group.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func barWidth(value: Double, maxMagnitude: Double, available: CGFloat) -> CGFloat {
        guard available > 0 else { return 2 }
        let ratio = min(abs(value) / max(maxMagnitude, 0.01), 1)
        return max(2, available * ratio)
    }

    // MARK: - Assistant

    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "ИИ-ассистент")
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text("Ассистент получит эту разбивку и скажет, что менять в системе: структуру, сессии, инструменты или требования к POI.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryButton(title: "Обсудить с ассистентом") {
                showAssistant = true
                Haptics.tap()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Hints

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Как считается")

            InfoHint(text: "Сессии — по UTC: Азия 00–07, Лондон 07–12, Нью-Йорк 12–17, поздний NY 17–21, вне сессий 21–24.")

            InfoHint(text: "Структура и POI берутся из метки сделки, а если её нет — из цикла дня: SOF → Reversal, вход против недельного потока → Correction, рабочий Key Level → тип POI.")

            InfoHint(text: "Сделки без цикла и без метки попадают в группу «Без метки» — разметьте их в карточке сделки, и они войдут в анализ.")
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нечего анализировать")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Закройте хотя бы одну сделку — раздел покажет результат по структуре рынка, сессиям, дням недели, инструментам и POI.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Tints

    private func toneColor(_ tone: BehaviorTone) -> Color {
        switch tone {
        case .positive:
            return Theme.green
        case .negative:
            return Theme.red
        case .neutral:
            return Theme.textSecondary
        }
    }

    private func toneIcon(_ tone: BehaviorTone) -> String {
        switch tone {
        case .positive:
            return "checkmark"
        case .negative:
            return "exclamationmark"
        case .neutral:
            return "info"
        }
    }
}

// MARK: - Bucket selection

struct BehaviorBucketSelection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let trades: [Trade]
}

// MARK: - Bucket sheet

private struct BehaviorBucketSheet: View {
    let selection: BehaviorBucketSelection

    @Environment(\.dismiss) private var dismiss

    private var group: BehaviorGroup {
        BehaviorGroup(
            id: selection.id,
            title: selection.title,
            subtitle: selection.subtitle,
            trades: selection.trades
        )
    }

    private var sortedTrades: [Trade] {
        selection.trades.sorted { closeDate($0) > closeDate($1) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(selection.subtitle)
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

                HStack(spacing: 10) {
                    BehaviorTile(title: "Сделок", value: "\(group.count)")
                    BehaviorTile(
                        title: "Win rate",
                        value: MarketBehaviorEngine.percentText(group.winRate),
                        tint: group.winRate >= 0.5 ? Theme.green : Theme.textSecondary
                    )
                    BehaviorTile(title: "Суммарно", value: Fmt.r(group.totalR), tint: rTint(group.totalR))
                }

                HStack(spacing: 10) {
                    BehaviorTile(
                        title: "Средний R",
                        value: MarketBehaviorEngine.averageText(group.averageR),
                        tint: rTint(group.averageR)
                    )
                    BehaviorTile(
                        title: "Профит-фактор",
                        value: MarketBehaviorEngine.profitFactorText(group.profitFactor)
                    )
                    BehaviorTile(title: "TP / SL", value: "\(group.wins) / \(group.losses)")
                }

                ForEach(sortedTrades) { trade in
                    tradeRow(trade)
                }
            }
            .padding(22)
        }
    }

    private func tradeRow(_ trade: Trade) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(trade.direction.rawValue)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(trade.direction == .long ? Theme.green : Theme.red)
                }
                Text(metaLine(trade))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(Fmt.r(trade.actualR))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rTint(trade.actualR))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard(cornerRadius: 16)
    }

    private func metaLine(_ trade: Trade) -> String {
        var parts = [
            Fmt.shortDay(trade.closedAt ?? trade.entryDate),
            trade.marketSession.rawValue
        ]
        if let structure = trade.structure {
            parts.append(structure.rawValue)
        }
        if let poi = trade.poiType {
            parts.append(poi.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    private func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

// MARK: - Tile

private struct BehaviorTile: View {
    let title: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

private func rTint(_ value: Double) -> Color {
    if value > 0.05 { return Theme.green }
    if value < -0.05 { return Theme.red }
    return Theme.textSecondary
}

//
//  DisciplineSystemView.swift
//  ICT Checklist
//
//  Дисциплина: сделки по системе против сделок вне неё.
//

import SwiftUI
import SwiftData

struct DisciplineSystemView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var showOutside = false

    private var report: DisciplineSummary {
        DisciplineEngine.summary(trades: trades)
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

                    if report.hasData {
                        shareCard
                            .reveal(.zoom, 1)
                        groupsCard
                            .reveal(.rise, 2)
                        trendCard
                            .reveal(.rise, 3)
                        checksCard
                            .reveal(.rise, 4)
                        actionsCard
                            .reveal(.rise, 5)
                        outsideButton
                            .reveal(.rise, 6)
                    } else {
                        emptyCard
                            .reveal(.rise, 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showOutside) {
            OutsideTradesSheet(
                trades: trades.filter { $0.result != .open && !$0.checklistComplete }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
        }
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
            SectionLabel(text: "Система · всё время")
            ScreenTitle(text: "Дисциплина")
            Text("Входы по чек-листу против входов вне его — и что стоит каждый пропущенный пункт.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Share

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int((report.share * 100).rounded()))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(report.share >= 0.8 ? Theme.green : Theme.orange)

                Text("входов по системе")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(report.share >= 0.8 ? Theme.green : Theme.orange)
                        .frame(width: max(4, proxy.size.width * CGFloat(min(max(report.share, 0), 1))))
                }
            }
            .frame(height: 8)

            Text("\(Fmt.deals(report.systemCount)) по системе · \(report.outsideCount) вне системы")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Groups

    private var groupsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Две книги")

            groupRow(
                title: "По системе",
                count: report.systemCount,
                avgR: report.systemAvgR,
                winRate: report.systemWinRate,
                tint: Theme.green
            )

            Divider()
                .overlay(Theme.hairline)

            groupRow(
                title: "Вне системы",
                count: report.outsideCount,
                avgR: report.outsideAvgR,
                winRate: report.outsideWinRate,
                tint: Theme.red
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func groupCardRow(
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupRow(
        title: String,
        count: Int,
        avgR: Double,
        winRate: Int,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                Text(Fmt.deals(count))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 10) {
                groupCardRow(title: "Средняя", value: Fmt.r(avgR), tint: tint)
                groupCardRow(title: "Winrate", value: "\(winRate)%", tint: Theme.textPrimary)
                groupCardRow(
                    title: "Итог",
                    value: Fmt.r(avgR * Double(count)),
                    tint: avgR >= 0 ? Theme.green : Theme.red
                )
            }
        }
    }

    // MARK: - Weekly trend

    private var trendCard: some View {
        let maxShare = 1.0

        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Недельный тренд дисциплины")

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(report.weeks) { week in
                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(week.share >= 0.8 ? Theme.green : (week.systemCount + week.outsideCount == 0 ? Color.white.opacity(0.08) : Theme.orange))
                            .frame(
                                width: 26,
                                height: max(6, CGFloat(min(max(week.share / maxShare, 0), 1)) * 84)
                            )
                        Text(week.label)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118)

            Text("Доля входов по системе за неделю. Зелёная — 80% и выше.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Checklist items

    private var checksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Пропущенные пункты")

            if report.checks.isEmpty {
                Text("Все пункты закрыты во всех сделках — так и держите.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(report.checks.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.item.title)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Пропущен \(row.missed) из \(report.closedCount)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer(minLength: 6)

                        Text(Fmt.r(row.costR))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(row.costR < -0.05 ? Theme.red : Theme.textSecondary)
                    }

                    if index < report.checks.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Три действия на неделю")

            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.background)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.accent))

                    Text(action)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var actions: [String] {
        var result: [String] = []

        if let worst = report.checks.first {
            result.append("Отмечайте «\(worst.item.title)» до входа: пропущено \(worst.missed) раз, \(Fmt.r(worst.costR)).")
        }
        if report.outsideCount > 0 {
            result.append("Разберите \(Fmt.deals(report.outsideCount)) вне системы: средняя \(Fmt.r(report.outsideAvgR)).")
        }
        if report.share < 0.8 {
            result.append("Доведите долю входов по системе до 80%: сейчас \(Int((report.share * 100).rounded()))%.")
        }
        while result.count < 3 {
            result.append("Держите чек-лист закрытым до входа: это единственное, что вы контролируете.")
        }
        return Array(result.prefix(3))
    }

    // MARK: - Outside trades

    private var outsideButton: some View {
        Button {
            showOutside = true
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("Показать сделки вне системы")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Text("\(report.outsideCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.orange.opacity(0.14)))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(report.outsideCount == 0)
        .opacity(report.outsideCount == 0 ? 0.5 : 1)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BreathingGlyph(systemName: "checkmark.seal")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            Text("Сделок пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Закройте сделки — и здесь появится дисциплина: сколько входов прошло по системе и что стоит каждый пропущенный пункт.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }
}

// MARK: - Outside trades sheet

private struct OutsideTradesSheet: View {
    let trades: [Trade]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сделки вне системы")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Чек-лист не закрыт полностью.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                if trades.isEmpty {
                    Text("Сделок вне системы нет.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(trades.enumerated()), id: \.element.persistentModelID) { index, trade in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trade.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(Fmt.dayMonth(trade.tradingDay)) · чек-лист \(trade.checkedChecks.count)/\(TradeCheck.allCases.count)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer(minLength: 4)
                                Text(Fmt.r(trade.actualR))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(trade.actualR < -0.05 ? Theme.red : Theme.green)
                            }
                            .padding(.vertical, 10)

                            if index < trades.count - 1 {
                                Divider()
                                    .overlay(Theme.hairline)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .glassCard(cornerRadius: 20)
                }
            }
            .padding(22)
        }
    }
}

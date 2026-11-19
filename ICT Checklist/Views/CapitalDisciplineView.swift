//
//  CapitalDisciplineView.swift
//  ICT Checklist
//
//  Цена своеволия: контрфактическая книга сделок вне системы.
//

import SwiftUI
import SwiftData

struct CapitalDisciplineView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]

    @State private var showViolations = false
    @State private var showPeriods = false

    private var activeAccounts: [TradingAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var portfolio: PortfolioReport {
        PortfolioEngine.report(
            accounts: activeAccounts,
            trades: trades,
            settings: settingsList.first,
            scope: nil
        )
    }

    private var report: DisciplineReport {
        CapitalDiscipline.report(
            trades: trades,
            capital: portfolio.capital,
            startCapital: portfolio.startCapital
        )
    }

    private var topViolations: [DisciplineViolation] {
        Array(report.violations.filter { $0.costR < -0.05 }.prefix(3))
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
                        resultCard
                            .reveal(.zoom, 1)
                        violationsCard
                            .reveal(.rise, 2)
                        periodsCard
                            .reveal(.rise, 3)
                        if !report.instruments.isEmpty {
                            instrumentsCard
                                .reveal(.rise, 4)
                        }
                        counterfactualCard
                            .reveal(.rise, 5)
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
        .sheet(isPresented: $showViolations) {
            ViolationsSheet(violations: report.violations)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showPeriods) {
            PeriodsSheet(periods: report.periods)
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
            ScreenTitle(text: "Цена своеволия")
            Text("\(Fmt.deals(report.outsideCount)) вне системы · \(report.systemCount) по системе")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Result

    private var resultCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                resultColumn(
                    title: "Реальный результат",
                    value: Fmt.r(report.realR),
                    tint: Theme.textPrimary
                )

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                resultColumn(
                    title: "Без нарушений",
                    value: Fmt.r(report.cleanR),
                    tint: Theme.green
                )
            }
            .padding(.vertical, 14)

            Divider()
                .overlay(Theme.hairline)

            Text(
                "Разница \(Fmt.r(report.violationR)) · \(Fmt.signedPercent(report.percentOfCapital)) капитала"
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.red)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: 24)
    }

    private func resultColumn(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Violations

    private var violationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Самые дорогие нарушения")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                allButton {
                    showViolations = true
                }
            }

            if topViolations.isEmpty {
                Text("Сделки вне системы не стоили денег: ни одно нарушение не закрылось в минус.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let maxCost = topViolations.first.map { abs($0.costR) } ?? 1

                ForEach(Array(topViolations.enumerated()), id: \.element.id) { index, row in
                    Button {
                        showViolations = true
                        Haptics.tap()
                    } label: {
                        violationRow(row, maxCost: maxCost)
                    }
                    .buttonStyle(.plain)

                    if index < topViolations.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func violationRow(_ row: DisciplineViolation, maxCost: Double) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(row.item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                bar(
                    share: maxCost > 0.01 ? min(abs(row.costR) / maxCost, 1) : 0,
                    tint: Theme.red
                )
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.r(row.costR))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.red)
                Text(Fmt.deals(row.count))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Periods

    private var periodsCard: some View {
        let periods = snapshotPeriods
        let maxBar = max(report.periods.map(\.barValue).max() ?? 0, 0.1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("По периодам")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Button {
                    showPeriods = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 4) {
                        Text("Все")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(periods) { period in
                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(period.isLoss ? Theme.red : Theme.textTertiary.opacity(0.7))
                            .frame(width: 26, height: barHeight(period.barValue, max: maxBar))
                        Text(period.label)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 134)

            HStack(spacing: 16) {
                legendDot(Theme.red, "Убыток от нарушений")
                legendDot(Theme.textTertiary, "Чисто по системе")
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var snapshotPeriods: [DisciplinePeriod] {
        report.periods
    }

    private func barHeight(_ value: Double, max maxValue: Double) -> CGFloat {
        guard maxValue > 0.01 else { return 6 }
        let share = min(max(value / maxValue, 0), 1)
        return max(6, CGFloat(share) * 96)
    }

    private func legendDot(_ tint: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Instruments

    private var instrumentsCard: some View {
        let maxCost = max(report.instruments.map { abs($0.violationR) }.max() ?? 0, 0.1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("По инструментам")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(report.instruments.enumerated()), id: \.element.id) { index, row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 4)
                        Text(Fmt.r(row.violationR))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(row.violationR < -0.05 ? Theme.red : Theme.textSecondary)
                    }

                    bar(
                        share: maxCost > 0.01 ? min(abs(row.violationR) / maxCost, 1) : 0,
                        tint: row.violationR < -0.05 ? Theme.red : Theme.textTertiary
                    )

                    Text("\(Fmt.deals(row.outsideCount)) вне системы")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }

                if index < report.instruments.count - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Counterfactual

    private var counterfactualCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Если бы не брали")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 10) {
                counterfactualTile(
                    title: "Было",
                    value: Fmt.r(report.realR),
                    tint: Theme.textPrimary
                )
                counterfactualTile(
                    title: "Стало бы",
                    value: Fmt.r(report.cleanR),
                    tint: Theme.green
                )
                counterfactualTile(
                    title: "Просадка",
                    value: Fmt.signedPercent(-report.realDrawdownPercent),
                    tint: Theme.red,
                    caption: "вместо \(Fmt.signedPercent(-report.cleanDrawdownPercent))"
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func counterfactualTile(
        title: String,
        value: String,
        tint: Color,
        caption: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(height: 86, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
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
            Text("Закройте сделки — и здесь появится цена своеволия: сколько R стоят входы вне системы.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Pieces

    private func allButton(_ action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            HStack(spacing: 4) {
                Text("Все")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func bar(share: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * CGFloat(min(max(share, 0), 1))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Violations sheet

private struct ViolationsSheet: View {
    let violations: [DisciplineViolation]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Нарушения")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Сколько R стоит каждый пропущенный пункт чек-листа.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                if violations.isEmpty {
                    Text("Нарушений нет: все закрытые сделки прошли чек-лист.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(violations.enumerated()), id: \.element.id) { index, row in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(Fmt.deals(row.count))
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer(minLength: 8)
                                Text(Fmt.r(row.costR))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(row.costR < -0.05 ? Theme.red : Theme.textSecondary)
                            }
                            .padding(.vertical, 10)

                            if index < violations.count - 1 {
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

// MARK: - Periods sheet

private struct PeriodsSheet: View {
    let periods: [DisciplinePeriod]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("По периодам")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Убыток от нарушений и чистый результат по системе.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                VStack(spacing: 0) {
                    ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                        HStack(spacing: 10) {
                            Text(period.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 70, alignment: .leading)

                            Text(Fmt.r(period.violationR))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(period.isLoss ? Theme.red : Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Text(Fmt.r(period.cleanR))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.green)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 10)

                        if index < periods.count - 1 {
                            Divider()
                                .overlay(Theme.hairline)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .glassCard(cornerRadius: 20)
            }
            .padding(22)
        }
    }
}

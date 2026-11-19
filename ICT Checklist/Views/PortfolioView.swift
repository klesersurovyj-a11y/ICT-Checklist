//
//  PortfolioView.swift
//  ICT Checklist
//
//  Портфель: капитал, открытый риск, просадка и риск-бюджет месяца
//  по всем счетам сразу или по одному выбранному.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]

    @State private var scopeID: String?
    @State private var showCapitalPlan = false

    private var activeAccounts: [TradingAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var scope: TradingAccount? {
        guard let scopeID else { return nil }
        return activeAccounts.first { "\($0.persistentModelID)" == scopeID }
    }

    private var report: PortfolioReport {
        PortfolioEngine.report(
            accounts: activeAccounts,
            trades: trades,
            settings: settingsList.first,
            scope: scope
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)

                    if activeAccounts.count > 1 {
                        scopePicker
                            .reveal(.zoom, 1)
                    }

                    if activeAccounts.isEmpty {
                        emptyCard
                            .reveal(.rise, 2)
                    } else {
                        heroCard
                            .reveal(.zoom, 2)
                        tilesRow
                            .reveal(.rise, 3)
                        budgetCard
                            .reveal(.rise, 4)
                        accountsCard
                            .reveal(.rise, 5)
                    }

                    capitalPlanButton
                        .reveal(.rise, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .fullScreenCover(isPresented: $showCapitalPlan) {
            GoalView()
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
            SectionLabel(text: "Фонд · Капитал")
            ScreenTitle(text: "Портфель")
            Text("Капитал, открытый риск и просадка по всем счетам сразу.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Scope picker

    private var scopePicker: some View {
        HStack(spacing: 4) {
            scopeChip("Все счета", id: nil, fill: true)
            ForEach(activeAccounts) { account in
                scopeChip(
                    account.name.isEmpty ? account.type.rawValue : account.name,
                    id: "\(account.persistentModelID)",
                    fill: true
                )
            }
        }
        .padding(4)
        .glassPanel(cornerRadius: 16)
    }

    private func scopeChip(_ title: String, id: String?, fill: Bool) -> some View {
        let isSelected = scopeID == id
        return Button {
            withAnimation(Theme.snappy) {
                scopeID = id
            }
            Haptics.select()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: fill ? .infinity : nil)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Капитал")

                    Text(money(report.capital))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(report.capital < -0.005 ? Theme.red : Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)

                    Text("\(signedPercent(report.monthPercent)) за месяц · \(signedMoney(report.monthMoney))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint(report.monthMoney))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                budgetRing
            }

            Divider()
                .overlay(Color.white.opacity(0.07))

            HStack(spacing: 0) {
                heroStat(title: "Эквити", value: Fmt.r(report.equityR), tint: tint(report.equityR))
                Spacer(minLength: 6)
                heroStat(title: "С начала", value: PortfolioEngine.percentText(report.totalPercent), tint: tint(report.totalPercent))
                Spacer(minLength: 6)
                heroStat(title: "Сегодня", value: Fmt.r(report.dayR), tint: tint(report.dayR))
                Spacer(minLength: 6)
                heroStat(title: "Неделя", value: Fmt.r(report.weekR), tint: tint(report.weekR))
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 26)
    }

    private func heroStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var budgetRing: some View {
        let share = report.budgetShare
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(share, 0.004))
                    .stroke(
                        share > 0.85 ? Theme.red : Theme.green,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int((share * 100).rounded()))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 84, height: 84)

            Text("риск-бюджет")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Tiles

    private var tilesRow: some View {
        HStack(spacing: 8) {
            MetricTile(
                title: "Открытый риск",
                value: PortfolioEngine.percentText(report.openRiskPercent),
                tint: report.openRiskPercent > 5 ? Theme.red : Theme.textPrimary
            )
            MetricTile(
                title: "Просадка",
                value: report.drawdownPercent > 0.05
                    ? "\u{2212}\(String(format: "%.1f%%", report.drawdownPercent))"
                    : "0.0%",
                tint: report.drawdownPercent > 0.05 ? Theme.red : Theme.textPrimary
            )
            MetricTile(
                title: "R за месяц",
                value: Fmt.r(report.monthR),
                tint: tint(report.monthR)
            )
        }
    }

    // MARK: - Budget

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Риск-бюджет месяца")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 0)

                Text("\(Int((report.budgetShare * 100).rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(report.budgetShare > 0.85 ? Theme.red : Theme.green)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(report.budgetShare > 0.85 ? Theme.red : Theme.green)
                        .frame(width: max(6, proxy.size.width * report.budgetShare))
                }
            }
            .frame(height: 8)

            Text("\(rValue(report.riskUsedR)) из \(rValue(report.riskBudgetR)) использовано")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()

            Text("до конца месяца \(daysText(report.daysLeft)) · лимит \(rValue(report.weeklyLimitR)) в неделю, \(report.weeksInMonth) \(weekWord(report.weeksInMonth))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Accounts

    private var accountsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Счета")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(report.slices.enumerated()), id: \.element.id) { index, slice in
                if index > 0 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                }
                accountRow(slice)
            }

            Text("Совокупный риск открытых позиций \(Fmt.money(report.openRiskUSD)) · \(PortfolioEngine.percentText(report.openRiskPercent)) капитала")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func accountRow(_ slice: PortfolioAccountSlice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(slice.name)
                    .font(.system(size: 14, weight: slice.isSelected ? .semibold : .medium))
                    .foregroundStyle(slice.isSelected ? Theme.textPrimary : .white.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(money(slice.equity))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)

                Text("\(Int((slice.share * 100).rounded()))%")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, alignment: .trailing)

                Text(Fmt.r(slice.monthR))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint(slice.monthR))
                    .frame(width: 52, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.white.opacity(slice.isSelected ? 0.85 : 0.45))
                        .frame(width: max(4, proxy.size.width * min(max(slice.share, 0), 1)), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Theme.snappy) {
                scopeID = slice.isSelected ? nil : slice.id
            }
            Haptics.tap()
        }
    }

    // MARK: - Plan

    private var capitalPlanButton: some View {
        PrimaryButton(title: "План капитала на месяц") {
            showCapitalPlan = true
            Haptics.tap()
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока нет счетов")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Создайте счёт в разделе «Счета» — и здесь появятся капитал, открытый риск, просадка и риск-бюджет месяца.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Formatting

    private func tint(_ value: Double) -> Color {
        if value > 0.005 { return Theme.green }
        if value < -0.005 { return Theme.red }
        return Theme.textPrimary
    }

    private func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = abs(value) >= 100 ? 0 : 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return text + " $"
    }

    private func signedMoney(_ value: Double) -> String {
        guard abs(value) >= 0.005 else { return money(0) }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + money(abs(value))
    }

    private func signedPercent(_ value: Double) -> String {
        guard abs(value) >= 0.05 else { return "0.0%" }
        let sign = value > 0 ? "+" : "\u{2212}"
        return sign + String(format: "%.1f%%", abs(value))
    }

    private func rValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0fR", value)
        }
        return String(format: "%.1fR", value)
    }

    private func daysText(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "\(count) дней" }
        if mod10 == 1 { return "\(count) день" }
        if mod10 >= 2 && mod10 <= 4 { return "\(count) дня" }
        return "\(count) дней"
    }

    private func weekWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "недель" }
        if mod10 == 1 { return "неделя" }
        if mod10 >= 2 && mod10 <= 4 { return "недели" }
        return "недель"
    }
}

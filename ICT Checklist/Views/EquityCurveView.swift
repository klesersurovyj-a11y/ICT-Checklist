//
//  EquityCurveView.swift
//  ICT Checklist
//
//  Капитал и просадка: кривая капитала в процентах и «подводная» кривая.
//

import SwiftUI
import SwiftData

struct EquityCurveView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var period: EquityCurvePeriod = .days90
    @State private var scopeID: String?

    private var activeAccounts: [TradingAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var scope: TradingAccount? {
        guard let scopeID else { return nil }
        return activeAccounts.first { "\($0.persistentModelID)" == scopeID }
    }

    private var scopeName: String {
        guard let scope else { return "Все счета" }
        return scope.name.isEmpty ? scope.type.rawValue : scope.name
    }

    private var report: EquityCurveReport {
        EquityCurveEngine.report(
            accounts: activeAccounts,
            trades: trades,
            scope: scope,
            period: period
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
                    periodRow
                        .reveal(.blur, 1)
                    equityCard
                        .reveal(.zoom, 2)
                    underwaterCard
                        .reveal(.rise, 3)
                    tilesRow
                        .reveal(.rise, 4)
                    keyDaysCard
                        .reveal(.rise, 5)
                    shareButton
                        .reveal(.rise, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
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
            SectionLabel(text: "Фонд · Эквити")
            ScreenTitle(text: "Капитал и просадка")
            Text("Рост капитала по закрытым сделкам и его просадки от пика.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodBinding: Binding<EquityCurvePeriod> {
        Binding(
            get: { period },
            set: { value in
                period = value
                Haptics.select()
            }
        )
    }

    private var periodRow: some View {
        HStack(spacing: 8) {
            GlassSegmented(
                options: EquityCurvePeriod.allCases,
                selection: periodBinding,
                label: { $0.rawValue }
            )

            accountMenu
        }
    }

    private var accountMenu: some View {
        Menu {
            Button {
                scopeID = nil
                Haptics.select()
            } label: {
                if scopeID == nil {
                    Label("Все счета", systemImage: "checkmark")
                } else {
                    Text("Все счета")
                }
            }

            ForEach(activeAccounts) { account in
                let key = "\(account.persistentModelID)"
                let title = account.name.isEmpty ? account.type.rawValue : account.name
                Button {
                    scopeID = key
                    Haptics.select()
                } label: {
                    if scopeID == key {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(accountLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPanel(cornerRadius: 14)
        }
    }

    private var accountLabel: String {
        if let scope {
            return scope.name.isEmpty ? scope.type.rawValue : scope.name
        }
        return "Все счета"
    }

    // MARK: - Equity

    private var equityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Fmt.groupedMoney(report.capital)) · \(Fmt.signedPercent(report.totalPercent)) с начала")
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("максимум \(Fmt.groupedMoney(report.maxCapital)) · \(maxDateText)")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)

            if report.isEmpty {
                emptyChartPlaceholder
            } else {
                EquityChartView(points: report.points)
                    .frame(height: 190)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var maxDateText: String {
        guard let date = report.maxCapitalDate else { return "—" }
        return Fmt.shortDay(date)
    }

    // MARK: - Drawdown

    private var underwaterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Под водой")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if report.isEmpty {
                emptyChartPlaceholder
            } else {
                DrawdownChartView(points: report.drawdown)
                    .frame(height: 150)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("максимум")
                        .foregroundStyle(Theme.textSecondary)
                    Text(
                        report.maxDrawdownPercent > 0.05
                            ? "\u{2212}\(String(format: "%.1f%%", report.maxDrawdownPercent))"
                            : "0.0%"
                    )
                    .foregroundStyle(Theme.red)
                }

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Text("текущая просадка")
                        .foregroundStyle(Theme.textSecondary)
                    Text(dayText(report.currentDrawdownDays))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .font(.system(size: 12.5, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var emptyChartPlaceholder: some View {
        Text("За этот период нет закрытых сделок.")
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            .multilineTextAlignment(.center)
    }

    // MARK: - Tiles

    private var tilesRow: some View {
        HStack(spacing: 8) {
            MetricTile(
                title: "Макс. просадка",
                value: report.maxDrawdownPercent > 0.05
                    ? "\u{2212}\(String(format: "%.1f%%", report.maxDrawdownPercent))"
                    : "0.0%",
                tint: Theme.red
            )
            MetricTile(
                title: "Восстановление",
                value: recoveryText,
                tint: Theme.textPrimary
            )
            MetricTile(
                title: "Лучший день",
                value: report.bestDay.map { Fmt.signedPercent($0.percent) } ?? "—",
                tint: Theme.green
            )
        }
    }

    private var recoveryText: String {
        guard report.maxDrawdownPercent > 0.05 else { return "—" }
        return String(format: "%.1f", report.recoveryFactor)
    }

    // MARK: - Key days

    private var keyDaysCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ключевые дни")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(keyDays.enumerated()), id: \.element.id) { index, day in
                if index > 0 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                }

                HStack(spacing: 10) {
                    Text(Fmt.shortDay(day.date))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer(minLength: 6)

                    Text(Fmt.signedPercent(day.percent))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(day.percent >= 0 ? Theme.green : Theme.red)

                    Text("\(day.trades) \(Fmt.dealWord(day.trades))")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 62, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }

            if keyDays.isEmpty {
                Text("Пока нет дней с результатом.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var keyDays: [EquityDayResult] {
        var days: [EquityDayResult] = []
        if let best = report.bestDay {
            days.append(best)
        }
        if let worst = report.worstDay, worst.id != report.bestDay?.id {
            days.append(worst)
        }
        return days
    }

    // MARK: - Share

    private var shareButton: some View {
        Button {
            Task { @MainActor in share() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text("Поделиться графиком")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func share() {
        guard let url = EquityCurveImage.make(report, scopeName: scopeName, period: period) else {
            SharePresenter.presentFailure("Не удалось собрать картинку графика.")
            Haptics.warning()
            return
        }

        Haptics.success()
        SharePresenter.share([url])
    }

    // MARK: - Formatting

    private func dayText(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "\(count) дней" }
        if mod10 == 1 { return "\(count) день" }
        if mod10 >= 2 && mod10 <= 4 { return "\(count) дня" }
        return "\(count) дней"
    }
}

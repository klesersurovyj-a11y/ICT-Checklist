//
//  MonthlyPerformanceView.swift
//  ICT Checklist
//
//  Месячный разбор в стиле AlexxxFX (THE EDGE): качество преимущества,
//  нарратив, асимметрия, дисциплина риска и план на следующий месяц.
//

import SwiftUI
import SwiftData

struct MonthlyPerformanceView: View {
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var month: Date = MonthlyPerformanceEngine.monthStart(.now)

    var body: some View {
        MonthlyPerformanceContent(
            report: MonthlyPerformanceEngine.report(
                month: month,
                trades: trades,
                settings: settingsList.first,
                accounts: accounts
            ),
            canGoForward: month < MonthlyPerformanceEngine.monthStart(.now),
            onShift: { shift($0) }
        )
    }

    private func shift(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        let start = MonthlyPerformanceEngine.monthStart(next)
        guard start <= MonthlyPerformanceEngine.monthStart(.now) else { return }
        withAnimation(Theme.snappy) {
            month = start
        }
        Haptics.tap()
    }
}

private struct MonthlyPerformanceContent: View {
    let report: MonthlyReport
    let canGoForward: Bool
    var onShift: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAssistant = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)
                    monthNav
                        .reveal(.zoom, 1)

                    if report.tradesCount == 0 {
                        emptyCard
                    } else {
                        heroCard
                            .reveal(.zoom, 2)
                        scoreCard
                            .reveal(.rise, 3)
                        verdictCard
                            .reveal(.rise, 4)
                        processCard
                            .reveal(.rise, 5)
                        weeksCard
                            .reveal(.rise, 6)
                        groupsCard
                            .reveal(.rise, 7)
                        nextStepsCard
                            .reveal(.rise, 8)
                        assistantCard
                            .reveal(.rise, 9)
                        hintCard
                            .reveal(.blur, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView(prefill: assistantPrompt)
        }
    }

    private var assistantPrompt: String {
        "Разбери мой месяц в стиле AlexxxFX: где был edge, где сетап без преимущества, что с нарративом и дисциплиной риска и что делать в следующем месяце. Данные:\n"
            + MonthlyPerformanceEngine.promptSummary(report)
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
            SectionLabel(text: "Monthly Review · AlexxxFX")
            ScreenTitle(text: "Месячный разбор")
            Text("Разбор месяца по логике THE EDGE: есть ли преимущество, держится ли нарратив, как работает асимметрия и дисциплина риска.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthNav: some View {
        HStack(spacing: 10) {
            Button {
                onShift(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .glassCircle()
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)
            Text(report.label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)

            Button {
                onShift(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoForward ? Color.white.opacity(0.85) : Theme.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(canGoForward ? 0.07 : 0.03)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("РЕЗУЛЬТАТ МЕСЯЦА")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textTertiary)
                    Text(Fmt.r(report.totalR))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rTint(report.totalR))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("\(Fmt.deals(report.tradesCount)) · \(Fmt.tradingDays(report.tradingDays))")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                gradeRing
            }

            HStack(spacing: 10) {
                MetricTile(
                    title: "Win rate",
                    value: MonthlyPerformanceEngine.percentText(report.winRate),
                    tint: report.winRate >= 0.5 ? Theme.green : Theme.textPrimary
                )
                MetricTile(
                    title: "Expectancy",
                    value: AlgorithmMonitorEngine.signed(report.expectancy),
                    tint: rTint(report.expectancy)
                )
                MetricTile(
                    title: "Profit factor",
                    value: report.profitFactor.map { String(format: "%.2f", $0) } ?? "—",
                    tint: (report.profitFactor ?? 0) >= 1.5 ? Theme.green : Theme.textPrimary
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: edgeIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(edgeTint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(edgeTint.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.edge.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(report.edge.detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 28)
    }

    private var gradeRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(Double(report.totalScore) / 100, 0), 1))
                .stroke(gradeTint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: report.totalScore)
            VStack(spacing: 0) {
                Text(report.grade)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeTint)
                Text("\(report.totalScore)/100")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 92, height: 92)
    }

    private var gradeTint: Color {
        switch report.grade {
        case "A": return Theme.green
        case "B": return Theme.textPrimary
        case "C": return Theme.textSecondary
        default: return Theme.red
        }
    }

    private var edgeTint: Color {
        switch report.edge {
        case .working: return Theme.green
        case .fragile: return Theme.textPrimary
        case .broken: return Theme.red
        case .insufficient: return Theme.textSecondary
        }
    }

    private var edgeIcon: String {
        switch report.edge {
        case .working: return "checkmark.shield"
        case .fragile: return "exclamationmark"
        case .broken: return "xmark.shield"
        case .insufficient: return "hourglass"
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "Оценка месяца")
                Spacer(minLength: 8)
                Text("\(report.totalScore)/100")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeTint)
            }

            ForEach(report.scores) { score in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(score.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 6)
                        Text("\(score.points)/20")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(score.points >= 14 ? Theme.green : (score.points < 8 ? Theme.red : Theme.textSecondary))
                    }
                    Text(score.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.05))
                            Capsule()
                                .fill(score.points >= 14 ? Theme.green : (score.points < 8 ? Theme.red : Theme.textSecondary))
                                .opacity(0.7)
                                .frame(width: max(2, proxy.size.width * min(max(score.value, 0), 1)))
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Verdicts

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Разбор по системе")

            ForEach(report.verdicts) { verdict in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: verdict.tone == .negative ? "exclamationmark" : (verdict.tone == .positive ? "checkmark" : "info"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(toneTint(verdict.tone))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(toneTint(verdict.tone).opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verdict.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(verdict.detail)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func toneTint(_ tone: BehaviorTone) -> Color {
        switch tone {
        case .positive: return Theme.green
        case .negative: return Theme.red
        case .neutral: return Theme.textSecondary
        }
    }

    // MARK: - Process & risk

    private var processCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Нарратив и процесс")
                SummaryTable(items: processItems)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Риск")
                SummaryTable(items: riskItems)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private var processItems: [SummaryItem] {
        [
            SummaryItem(
                title: "Сделок по плану",
                value: MonthlyPerformanceEngine.percentText(report.planShare),
                tint: report.planShare >= 0.8 ? Theme.green : Theme.textPrimary
            ),
            SummaryItem(
                title: "Чек-лист закрыт",
                value: MonthlyPerformanceEngine.percentText(report.checklistShare),
                tint: report.checklistShare >= 0.8 ? Theme.green : Theme.textPrimary
            ),
            SummaryItem(
                title: "Маршрут A→B",
                value: MonthlyPerformanceEngine.percentText(report.narrativeShare),
                tint: report.narrativeShare >= 0.7 ? Theme.green : Theme.textPrimary
            ),
            SummaryItem(
                title: "Разбор сделок",
                value: MonthlyPerformanceEngine.percentText(report.reviewShare),
                tint: report.reviewShare >= 0.8 ? Theme.green : Theme.textPrimary
            )
        ]
    }

    private var riskItems: [SummaryItem] {
        var items: [SummaryItem] = [
            SummaryItem(title: "Средний риск", value: Fmt.money(report.averageRiskUSD))
        ]
        if let percent = report.averageRiskPercent {
            items.append(
                SummaryItem(
                    title: "Риск от капитала",
                    value: MonthlyPerformanceEngine.percentText(percent),
                    tint: report.overRiskCount > 0 ? Theme.red : Theme.green
                )
            )
        }
        items.append(
            SummaryItem(
                title: "Выше лимита",
                value: "\(report.overRiskCount)",
                tint: report.overRiskCount > 0 ? Theme.red : Theme.textPrimary
            )
        )
        items.append(
            SummaryItem(
                title: "Не по ступени",
                value: "\(report.ladderMismatch)",
                tint: report.ladderMismatch > 0 ? Theme.red : Theme.textPrimary
            )
        )
        items.append(
            SummaryItem(
                title: "Макс. просадка",
                value: Fmt.r(-report.maxDrawdown),
                tint: report.maxDrawdown > 0.05 ? Theme.red : Theme.textPrimary
            )
        )
        items.append(
            SummaryItem(
                title: "TP / SL / BE",
                value: "\(report.wins) / \(report.losses) / \(report.breakEvens)"
            )
        )
        return items
    }

    // MARK: - Weeks

    private var weeksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "По неделям")
                Spacer(minLength: 8)
                Text("\(report.weeks.filter { $0.trades > 0 }.count) недель в работе")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            ForEach(report.weeks) { week in
                HStack(spacing: 8) {
                    Text(week.label)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 52, alignment: .leading)

                    Text("\(week.trades) сд.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 42, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.05))
                            Capsule()
                                .fill(rTint(week.totalR).opacity(0.6))
                                .frame(width: barWidth(week.totalR, available: proxy.size.width))
                        }
                    }
                    .frame(height: 4)

                    Text(Fmt.r(week.totalR))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rTint(week.totalR))
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private var maxWeekMagnitude: Double {
        max(0.01, report.weeks.map { abs($0.totalR) }.max() ?? 0)
    }

    private func barWidth(_ value: Double, available: CGFloat) -> CGFloat {
        let ratio = min(abs(value) / maxWeekMagnitude, 1)
        return max(2, available * ratio)
    }

    // MARK: - Where it worked

    private var groupsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Где работало")
                groupRows(report.structures)
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Сессии")
                groupRows(report.sessions)
            }

            if report.intraday != nil || report.swing != nil {
                Divider()
                    .overlay(Color.white.opacity(0.06))
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Формат")
                    if let intraday = report.intraday, intraday.trades > 0 {
                        groupRow(intraday)
                    }
                    if let swing = report.swing, swing.trades > 0 {
                        groupRow(swing)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func groupRows(_ groups: [MonthGroup]) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(groups.prefix(6))) { group in
                groupRow(group)
            }
        }
    }

    private func groupRow(_ group: MonthGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(group.trades) сд.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 6)
            Text(MonthlyPerformanceEngine.percentText(group.winRate))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            Text(Fmt.r(group.totalR))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rTint(group.totalR))
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Next month

    private var nextStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "План на следующий месяц")
                Spacer(minLength: 8)
                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            ForEach(Array(report.nextSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 9) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.background)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.accent))
                    Text(step)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
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

            Text("Ассистент получит месяц, оценки и вердикты и разберёт их в стиле THE EDGE: нарратив, сетапы, риск и следующий шаг.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryButton(title: "Обсудить месяц с ассистентом") {
                showAssistant = true
                Haptics.tap()
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Hints

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Как читать разбор")

            InfoHint(text: "Сначала смотри на edge: profit factor и expectancy. Сетап без преимущества — просто сетап, поэтому месяц оценивается по цифрам, а не по количеству входов.")

            InfoHint(text: "Нарратив: доля сделок с планом, закрытым чек-листом и маршрутом A→B. Если маршрут не зафиксирован до входа, это уже не система, а импровизация.")

            InfoHint(text: "Асимметрия и риск: средний TP против среднего SL, превышения лимита и расхождения со ступенью лестницы. Оценка месяца — сумма пяти блоков по 20 баллов.")
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("За этот месяц закрытых сделок нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Выберите другой месяц стрелками сверху — разбор строится по закрытым сделкам, планам и разборам.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }
}

private func rTint(_ value: Double) -> Color {
    if value > 0.05 { return Theme.green }
    if value < -0.05 { return Theme.red }
    return Theme.textSecondary
}

//
//  SetupWeightsView.swift
//  ICT Checklist
//
//  Веса сетапов: цель из мандата, факт и предложение ребаланса.
//

import SwiftUI
import SwiftData

struct SetupWeightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \FundMandate.version, order: .reverse) private var mandates: [FundMandate]
    @Query(sort: \PlaybookSetup.createdAt) private var setups: [PlaybookSetup]

    private var activeMandate: FundMandate? {
        FundMandate.active(in: mandates)
    }

    private var report: SetupWeightsReport {
        SetupWeights.report(
            trades: trades,
            mandate: activeMandate,
            setups: setups
        )
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

                    if !report.hasMandate {
                        noMandateCard
                            .reveal(.rise, 1)
                    } else if report.rows.isEmpty {
                        noSetupsCard
                            .reveal(.rise, 1)
                    } else {
                        weightsCard
                            .reveal(.zoom, 1)
                        contributionCard
                            .reveal(.rise, 2)
                        proposalCard
                            .reveal(.rise, 3)
                        newVersionButton
                            .reveal(.rise, 4)
                    }
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
            SectionLabel(text: "Мандат · веса сетапов")
            ScreenTitle(text: "Веса сетапов")
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        if let activeMandate {
            return "Цель из мандата v\(activeMandate.version) · период 90 дней"
        }
        return "Нужен активный мандат · период 90 дней"
    }

    // MARK: - Weights

    private var weightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сейчас и цель")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(report.rows) { row in
                weightRow(row)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func weightRow(_ row: SetupWeightInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(row.name)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let targetX = width * CGFloat(min(max(row.target, 0), 100)) / 100
                    let actualX = width * CGFloat(min(max(row.actual, 0), 100)) / 100

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)

                        Circle()
                            .fill(Theme.textTertiary)
                            .frame(width: 13, height: 13)
                            .offset(x: max(0, min(targetX - 6.5, width - 13)))

                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .offset(x: max(0, min(actualX - 6.5, width - 13)))
                    }
                }
                .frame(height: 13)

                HStack(spacing: 0) {
                    Text("\(Int(row.target.rounded()))%")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text("\(Int(row.actual.rounded()))%")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 12) {
                    Text("Цель")
                        .frame(width: 40, alignment: .trailing)
                    Text("Факт")
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)

                HStack(spacing: 12) {
                    Text("\(Int(row.target.rounded()))%")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(Int(row.actual.rounded()))%")
                        .frame(width: 44, alignment: .trailing)
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()

                chip(for: row)
            }
            .frame(width: 108, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func chip(for row: SetupWeightInfo) -> some View {
        if row.isOver {
            chipText("перевес +\(Int(row.excess.rounded())) п.п.", tint: Theme.red)
        } else if row.isUnder {
            chipText("недобор \(Int(row.excess.rounded())) п.п.", tint: Theme.green)
        } else {
            chipText("в норме", tint: Theme.textSecondary)
        }
    }

    private func chipText(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    // MARK: - Contribution

    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Вклад в результат")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(report.rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer(minLength: 6)

                    Text("\(row.count) \(dealWord(row.count))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)

                    Text(Fmt.r(row.r))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(row.r >= -0.05 ? Theme.green : Theme.red)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if index < report.rows.count - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func dealWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "сделка" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "сделки" }
        return "сделок"
    }

    // MARK: - Proposal

    private var proposalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Предложение")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(report.proposal.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer(minLength: 6)

                    Text("\(Int(row.target.rounded()))%")
                        .font(.system(size: 14.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)

                    Text("\(Int(row.proposed.rounded()))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if index < report.proposal.count - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                }
            }

            Text(report.note)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var newVersionButton: some View {
        Button {
            createMandateVersion()
        } label: {
            Text("Новая версия мандата")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Empty

    private var noMandateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нет активного мандата")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Веса сетапов берутся из мандата фонда. Создайте его в комплаенсе — и здесь появятся цели по сетапам.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var noSetupsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сетапов пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Создайте сетапы в плейбуке или отметьте сетап у сделок — и здесь появятся веса.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Actions

    private func createMandateVersion() {
        guard let source = activeMandate else { return }

        for mandate in mandates {
            mandate.isActive = false
        }

        let version = FundMandate(
            version: FundMandate.nextVersion(in: mandates),
            note: noteText,
            isActive: true
        )
        version.riskPerTradePercent = source.riskPerTradePercent
        version.riskPerDayPercent = source.riskPerDayPercent
        version.riskPerMonthPercent = source.riskPerMonthPercent
        version.maxTradesPerDay = source.maxTradesPerDay
        version.maxInstrumentPercent = source.maxInstrumentPercent
        version.maxGroupPercent = source.maxGroupPercent
        version.maxFactorPercent = source.maxFactorPercent
        version.setupWeights = Dictionary(
            uniqueKeysWithValues: report.proposal.map { ($0.name, $0.proposed) }
        )

        context.insert(version)
        try? context.save()
        Haptics.success()
    }

    private var noteText: String {
        let changes = report.proposal
            .filter { abs($0.proposed - $0.target) > 0.1 }
            .map { "\($0.name) \(Int($0.target.rounded())) → \(Int($0.proposed.rounded()))%" }
            .joined(separator: ", ")
        if changes.isEmpty {
            return "Пересборка весов: без изменений"
        }
        return "Пересборка весов: \(changes)"
    }
}

//
//  CorrelationView.swift
//  ICT Checklist
//
//  Корреляции инструментов и концентрация открытого риска.
//

import SwiftUI
import SwiftData

struct CorrelationView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var period: CorrelationPeriod = .days90
    @State private var showTrades = false

    private var report: CorrelationReport {
        CorrelationEngine.report(trades: trades, accounts: accounts, period: period)
    }

    private var periodBinding: Binding<CorrelationPeriod> {
        Binding(
            get: { period },
            set: { value in
                period = value
                Haptics.select()
            }
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

                    GlassSegmented(
                        options: CorrelationPeriod.allCases,
                        selection: periodBinding,
                        label: { $0.rawValue }
                    )
                    .reveal(.blur, 1)

                    matrixCard
                        .reveal(.zoom, 2)
                    tilesRow
                        .reveal(.rise, 3)

                    if report.warning != nil {
                        warningCard
                            .reveal(.rise, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .fullScreenCover(isPresented: $showTrades) {
            TradesView()
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
            SectionLabel(text: "Фонд · Риск")
            ScreenTitle(text: "Корреляции")
            Text("Какие инструменты двигаются вместе и сколько риска в одной ставке.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Matrix

    private var matrixCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Матрица корреляции")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if report.isEmpty {
                Text("Нужно хотя бы два инструмента с тремя общими днями закрытых сделок за период.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Color.clear
                            .frame(width: 62, height: 1)
                        ForEach(report.symbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    ForEach(report.symbols, id: \.self) { row in
                        HStack(spacing: 4) {
                            Text(row)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(width: 62, alignment: .leading)

                            ForEach(report.symbols, id: \.self) { column in
                                cell(row, column)
                            }
                        }
                    }
                }

                legend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func cell(_ row: String, _ column: String) -> some View {
        let value = report.value(row, column) ?? 0
        return Text(String(format: "%.2f", value))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint(for: value))
            )
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("\u{2212}1")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            LinearGradient(
                colors: [Theme.green, Color(hex: 0x8A8C86), Color(hex: 0xE87045)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())

            Text("+1")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 2)
    }

    private func correlationColor(_ value: Double) -> Color {
        let magnitude = min(abs(value), 1)
        if value > 0.005 {
            return Color(hex: 0xE87045).opacity(0.20 + 0.55 * magnitude)
        }
        if value < -0.005 {
            return Theme.green.opacity(0.18 + 0.50 * magnitude)
        }
        return Color.white.opacity(0.06)
    }

    private func correlationTextColor(_ value: Double) -> Color {
        if value > 0.005 { return Color(hex: 0xE87045) }
        if value < -0.005 { return Theme.green }
        return Theme.textPrimary
    }

    // MARK: - Tiles

    private var tilesRow: some View {
        HStack(alignment: .top, spacing: 8) {
            pairTile
            concentrationTile
        }
    }

    private var pairTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Самая высокая связь")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let pair = report.topPair {
                Text("\(pair.a) ↔ \(pair.b)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(String(format: "%.2f", pair.value))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(correlationTextColor(pair.value))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(pair.commonDays) \(Fmt.dealWord(pair.commonDays)) вместе")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Нет общих дней")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    private var concentrationTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Концентрация")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if let concentration = report.concentration {
                Text(concentration.symbol)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text("\(Int((concentration.share * 100).rounded()))% риска")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Color(hex: 0xE87045))
                            .frame(width: max(6, proxy.size.width * min(max(concentration.share, 0), 1)))
                    }
                }
                .frame(height: 6)

                Text("из них \(Int((concentration.sameDirectionShare * 100).rounded()))% в одну сторону")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let group = report.group {
                    Text("группа \(group.symbols.joined(separator: " + ")) — \(Int((group.share * 100).rounded()))% риска")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text("Открытых сделок нет")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Warning

    private var warningCard: some View {
        Group {
            if let warning = report.warning {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xE8A33C))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Открытые сделки в одну сторону")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)

                            Text(warningText(warning))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Button {
                        showTrades = true
                        Haptics.tap()
                    } label: {
                        Text("Открыть сделки")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 22)
            }
        }
    }

    private func warningText(_ warning: CorrelationWarning) -> String {
        let pair = "\(warning.firstSymbol) \(warning.firstDirection.rawValue) и \(warning.secondSymbol) \(warning.secondDirection.rawValue)"
        let link = String(format: "%.2f", warning.correlation)
        let share = String(format: "%.1f%%", warning.capitalShare)
        return "\(pair) — связь \(link), суммарный риск \(share) капитала"
    }

    private func tint(for value: Double) -> Color {
        correlationColor(value)
    }
}

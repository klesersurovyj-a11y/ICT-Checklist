//
//  WorldEconomyView.swift
//  ICT Checklist
//
//  Мировая карта: экономика ключевых регионов и её влияние на коренные активы.
//

import SwiftUI
import SwiftData
import MapKit

struct WorldEconomyView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]
    @Query(sort: \BankRateRevision.createdAt, order: .reverse)
    private var rateRevisions: [BankRateRevision]

    @State private var region: EconomyRegion = .usa
    @State private var snapshots: [String: EconomySnapshot] = [:]
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showCapitalFlows = false
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45, longitude: -25),
            span: MKCoordinateSpan(latitudeDelta: 55, longitudeDelta: 110)
        )
    )

    private var snapshot: EconomySnapshot? {
        snapshots[region.countryCode]
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    mapCard
                        .reveal(.zoom, 1)

                    regionPicker
                        .reveal(.blur, 2)

                    economyCard
                        .reveal(.rise, 3)

                    assetsCard
                        .reveal(.rise, 4)

                    impactCard
                        .reveal(.rise, 5)

                    capitalFlowsCard
                        .reveal(.rise, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .task {
            snapshots = WorldEconomyService.loadCache()
            await refresh()
        }
        .fullScreenCover(isPresented: $showCapitalFlows) {
            CapitalFlowsView(initialRegion: region)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Макро · Мировая карта")
                ScreenTitle(text: "Экономики и активы")
                Text("Ключевые экономики, их показатели и то, как это отражается на валюте и индексах региона.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .windIn(delay: 0.8)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {
                    Task { await refresh() }
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

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
    }

    // MARK: - Map

    private var mapCard: some View {
        Map(position: $camera) {
            ForEach(EconomyRegion.allCases) { item in
                Annotation(item.rawValue, coordinate: item.coordinate) {
                    Button {
                        select(item)
                    } label: {
                        Text(item.currency)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(item == region ? Theme.background : Theme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    item == region ? Theme.accent : Color.black.opacity(0.55)
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    item == region ? Color.clear : Color.white.opacity(0.25),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func select(_ item: EconomyRegion) {
        withAnimation(Theme.snappy) {
            region = item
        }
        camera = .region(
            MKCoordinateRegion(
                center: item.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 70)
            )
        )
        Haptics.select()
    }

    // MARK: - Region picker

    private var regionPicker: some View {
        HStack(spacing: 8) {
            ForEach(EconomyRegion.allCases) { item in
                Button {
                    select(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(item.currency)
                            .font(.system(size: 10))
                            .foregroundStyle(item == region ? Theme.background.opacity(0.7) : Theme.textTertiary)
                    }
                    .foregroundStyle(item == region ? Theme.background : Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(item == region ? Theme.accent : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Capital flows

    private var capitalFlowsCard: some View {
        let profile = CapitalFlows.profile(for: region)
        let window = CapitalFlows.rebalancingWindow()
        let windowTint = window.active ? Theme.orange : Theme.textTertiary
        let overrideRate = BankOverrides.rate(profile.region.currency)
        let bankRateText = overrideRate.isEmpty ? profile.policy.metrics.policyRate : overrideRate

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Потоки капитала")
                Spacer(minLength: 4)
                Text(window.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(windowTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(windowTint.opacity(0.14)))
            }

            Text("\(profile.policy.bank) · \(profile.biasTitle)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(profile.tint)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(bankRateText) · \(profile.policy.expected.direction.lowercased()) · bias \(profile.policy.bias.label.lowercased())")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(profile.policy.bias.tint)
                .fixedSize(horizontal: false, vertical: true)

            if let revision = BankRatesLog.latest(rateRevisions, currency: profile.region.currency) {
                Text(BankRatesLog.freshnessText(revision))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(BankRatesLog.isStale(revision) ? Theme.orange : Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ревизий ставки нет — база по умолчанию")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(profile.policy.currencyEffect)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    miniFlowPill("Пенсионные фонды", tint: Theme.lavender)
                    miniFlowPill("Хедж выручки", tint: Theme.blue)
                    miniFlowPill("Trend following", tint: Theme.green)
                }
            }

            Button {
                showCapitalFlows = true
                Haptics.tap()
            } label: {
                HStack(spacing: 6) {
                    Text("Мотив, фонды и хедж")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func miniFlowPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    // MARK: - Economy

    private var economyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(region.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(region.centralBank)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }

            Text(region.session)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)

            if snapshot == nil && isLoading {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            SkeletonBar(width: 46, height: 7)
                            SkeletonBar(width: 62, height: 13)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .glassPanel(cornerRadius: 12)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    indicatorTile(
                        "Рост ВВП",
                        WorldEconomyService.percentText(snapshot?.growth),
                        tint: growthTint
                    )
                    indicatorTile(
                        "Инфляция",
                        WorldEconomyService.percentText(snapshot?.inflation),
                        tint: inflationTint
                    )
                    indicatorTile(
                        "Безработица",
                        WorldEconomyService.percentText(snapshot?.unemployment),
                        tint: Theme.textPrimary
                    )
                    indicatorTile(
                        "ВВП",
                        WorldEconomyService.gdpText(snapshot?.gdpUSD),
                        tint: Theme.textPrimary
                    )
                }
            }

            Text(footnote)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var footnote: String {
        if let errorText {
            return "Не удалось обновить данные: \(errorText). Показаны последние загруженные."
        }
        if let year = snapshot?.year {
            return "Источник: Всемирный банк · последние доступные данные за \(year) год и ранее"
        }
        return "Источник: Всемирный банк. Данные загружаются при открытии экрана."
    }

    private func indicatorTile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var growthTint: Color {
        guard let growth = snapshot?.growth else { return Theme.textPrimary }
        if growth >= 1 { return Theme.green }
        if growth < 0 { return Theme.red }
        return Theme.textPrimary
    }

    private var inflationTint: Color {
        guard let inflation = snapshot?.inflation else { return Theme.textPrimary }
        return inflation >= 4 ? Theme.orange : Theme.textPrimary
    }

    // MARK: - Assets

    private var assetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Коренные активы")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(region.nativeAssets, id: \.self) { asset in
                let stats = assetStats(asset)
                HStack(spacing: 8) {
                    Text(asset)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 72, alignment: .leading)

                    Text("\(stats.trades) \(Fmt.dealWord(stats.trades))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer(minLength: 0)

                    if stats.trades > 0 {
                        Text("\(Int((stats.winRate * 100).rounded()))%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, alignment: .trailing)

                        Text(Fmt.r(stats.totalR))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rTint(stats.totalR))
                            .frame(width: 54, alignment: .trailing)
                    } else {
                        Text("нет сделок")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.vertical, 3)
            }

            Text("Результат — по вашим закрытым сделкам в этих инструментах.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private struct AssetStats {
        let trades: Int
        let winRate: Double
        let totalR: Double
    }

    private func assetStats(_ asset: String) -> AssetStats {
        let matched = trades.filter {
            $0.result != .open && $0.symbol.localizedCaseInsensitiveContains(asset)
        }
        guard !matched.isEmpty else {
            return AssetStats(trades: 0, winRate: 0, totalR: 0)
        }
        let wins = matched.filter { $0.actualR > 0.05 }.count
        return AssetStats(
            trades: matched.count,
            winRate: Double(wins) / Double(matched.count),
            totalR: matched.reduce(0) { $0 + $1.actualR }
        )
    }

    private func rTint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textPrimary
    }

    // MARK: - Impact

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Как это влияет")

            if let snapshot {
                Text(WorldEconomyService.impactText(for: snapshot))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Показатели ещё не загружены. Обновите данные — и здесь появится вывод о влиянии на валюту и индекс региона.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Load

    @MainActor
    private func refresh() async {
        isLoading = true
        errorText = nil
        do {
            let loaded = try await WorldEconomyService.fetch()
            snapshots = loaded
        } catch {
            errorText = error.localizedDescription
            if snapshots.isEmpty {
                snapshots = WorldEconomyService.loadCache()
            }
        }
        isLoading = false
    }
}

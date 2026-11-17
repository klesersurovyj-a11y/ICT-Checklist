//
//  AchievementsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var trades: [Trade]
    @Query private var goals: [MonthlyGoal]

    private var items: [AchievementItem] {
        Achievements.items(trades: trades, goals: goals)
    }

    private var achievedCount: Int {
        items.filter(\.isAchieved).count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .reveal(.slideLeft)
                    collectedCard
                        .reveal(.zoom, 1)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            tile(item)
                                .reveal(.rise, index + 2)
                        }
                    }

                    Text("Достижения считаются по закрытым сделкам и ничего не меняют")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Статистика")
                ScreenTitle(text: "Достижения")
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Collected

    private var collectedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Собрано")

            HStack(alignment: .center, spacing: 14) {
                Text("\(achievedCount) из \(items.count)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 8)

                segmentedBar(items.isEmpty ? 0 : Double(achievedCount) / Double(items.count), tint: Theme.textPrimary)
                    .frame(width: 120)
            }

            Text("Рекорды собираются из закрытых сделок")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Tile

    private func tile(_ item: AchievementItem) -> some View {
        let tint: Color = item.isAchieved ? Theme.textPrimary : Theme.textTertiary

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(item.isAchieved ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                        .frame(width: 30, height: 30)
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item.isAchieved ? Theme.textPrimary : Theme.textTertiary)
                }

                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Text(item.value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            if let progress = item.progress, item.isAchieved {
                segmentedBar(progress, tint: Theme.textPrimary)
            }

            Text(item.caption)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(13)
        .glassCard(cornerRadius: 18)
    }

    private func segmentedBar(_ value: Double, tint: Color) -> some View {
        let filled = max(0, min(12, Int((value * 12).rounded())))

        return HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? tint.opacity(0.85) : Color.white.opacity(0.08))
                    .frame(height: 4)
            }
        }
    }
}

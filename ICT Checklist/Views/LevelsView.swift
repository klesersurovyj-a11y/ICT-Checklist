//
//  LevelsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct LevelsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TradingCycle.day, order: .reverse)
    private var cycles: [TradingCycle]

    @State private var selectedType: KeyLevelType?
    @State private var onlyActive = false
    @State private var selectedCycle: TradingCycle?

    private struct Entry: Identifiable {
        let id: String
        let level: KeyLevel
        let cycle: TradingCycle
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let day: Date
        let entries: [Entry]
    }

    // MARK: - Data

    private var entries: [Entry] {
        var items: [Entry] = []
        for cycle in cycles {
            for level in cycle.keyLevels {
                items.append(
                    Entry(
                        id: "\(cycle.persistentModelID.hashValue)-\(level.persistentModelID.hashValue)",
                        level: level,
                        cycle: cycle
                    )
                )
            }
        }
        return items
    }

    private var filteredEntries: [Entry] {
        entries.filter { entry in
            if onlyActive && entry.level.absorbed { return false }
            if let selectedType, entry.level.type != selectedType { return false }
            return true
        }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) {
            calendar.startOfDay(for: $0.cycle.day)
        }
        return grouped
            .map { day, items in
                DayGroup(
                    id: day,
                    day: day,
                    entries: items.sorted { $0.level.createdAt > $1.level.createdAt }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private var activeCount: Int {
        entries.filter { !$0.level.absorbed }.count
    }

    private var absorbedCount: Int {
        entries.filter { $0.level.absorbed }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)
                    typeChips
                        .reveal(.blur, 1)
                    activeToggle
                        .reveal(.rise, 2)

                    if groups.isEmpty {
                        emptyCard
                    } else {
                        ForEach(groups) { group in
                            daySection(group)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $selectedCycle) { cycle in
            LevelsCycleSheet(cycle: cycle)
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
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Уровни")
            ScreenTitle(text: "Ключевые уровни")
            Text("\(activeCount) активных · \(absorbedCount) погашено")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filters

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(nil)
                ForEach(KeyLevelType.allCases) { type in
                    typeChip(type)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func typeChip(_ type: KeyLevelType?) -> some View {
        let isSelected = selectedType == type
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedType = type
            }
            Haptics.select()
        } label: {
            Text(type?.rawValue ?? "Все")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Theme.textPrimary.opacity(0.8))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? Theme.accent : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var activeToggle: some View {
        Toggle(isOn: $onlyActive) {
            Text("Только активные")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - List

    private func daySection(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Fmt.shortDay(group.day).uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)

            ForEach(group.entries) { entry in
                levelRow(entry)
            }
        }
    }

    private func levelRow(_ entry: Entry) -> some View {
        let tint = entry.level.type.tint

        return Button {
            selectedCycle = entry.cycle
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text(entry.level.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(tint.opacity(0.16)))

                    Spacer(minLength: 8)

                    Text(distanceText(entry))
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(Fmt.price(entry.level.price))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 10)

                    Text(entry.level.absorbed ? "поглощён" : "активен")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(entry.level.absorbed ? Theme.textSecondary : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                entry.level.absorbed
                                    ? Color.white.opacity(0.08)
                                    : Theme.green.opacity(0.75)
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func distanceText(_ entry: Entry) -> String {
        guard let reference = entry.cycle.referencePrice, reference != 0 else {
            return "—"
        }
        let diff = entry.level.price - reference
        let percent = abs(diff) / reference * 100
        let sign = diff > 0 ? "+" : (diff < 0 ? "\u{2212}" : "")
        return sign + String(format: "%.2f%%", percent)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entries.isEmpty ? "Пока нет уровней" : "Ничего не найдено")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                entries.isEmpty
                    ? "Key Levels появятся здесь, когда вы добавите их в цикле «Сегодня» на шаге KEY LEVELS."
                    : "Смените тип или выключите «Только активные» — сами уровни не менялись."
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}

// MARK: - Cycle sheet

private struct LevelsCycleSheet: View {
    let cycle: TradingCycle

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Цикл дня")
                            Text(Fmt.day(cycle.day))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Button("Закрыть") {
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }

                    DayResultView(cycle: cycle)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}

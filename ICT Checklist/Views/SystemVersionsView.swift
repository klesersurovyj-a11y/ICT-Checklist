//
//  SystemVersionsView.swift
//  ICT Checklist
//
//  Версии торговой системы: активная версия, история, результат и откат.
//

import SwiftUI
import SwiftData

struct SystemVersionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \SystemVersion.version, order: .reverse) private var versions: [SystemVersion]
    @Query(sort: \Trade.entryDate, order: .reverse) private var trades: [Trade]

    @State private var change = ""
    @State private var hypothesis = ""
    @State private var metric = ""
    @State private var checkAfter = 20

    @State private var showRollback = false
    @State private var rollbackReason = ""
    @State private var showHistory = false
    @State private var detail: SystemVersion?

    private var activeVersion: SystemVersion? {
        SystemVersions.active(versions)
    }

    private var previousVersion: SystemVersion? {
        SystemVersions.previous(versions, of: activeVersion)
    }

    private var historyVersions: [SystemVersion] {
        SystemVersions.sorted(versions).filter { $0.isActive == false }
    }

    private var canSave: Bool {
        !change.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                    if let activeVersion {
                        activeCard(activeVersion)
                            .reveal(.zoom, 1)
                    } else {
                        noVersionCard
                            .reveal(.rise, 1)
                    }

                    if !historyVersions.isEmpty {
                        historyCard
                            .reveal(.rise, 2)
                    }

                    newVersionCard
                        .reveal(.rise, 3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showRollback) {
            rollbackSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showHistory) {
            VersionHistorySheet(versions: versions, trades: trades)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(item: $detail) { version in
            VersionDetailSheet(version: version, trades: trades)
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
            SectionLabel(text: "Система · история")
            ScreenTitle(text: "Версии")
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        guard let activeVersion else {
            return versions.isEmpty ? "Версий пока нет" : "\(versions.count) версий · активной нет"
        }
        return "Активна v\(activeVersion.version) · \(Fmt.shortDay(activeVersion.createdAt)) · \(versions.count) \(versionWord(versions.count))"
    }

    private func versionWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "версия" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "версии" }
        return "версий"
    }

    // MARK: - Active

    private func activeCard(_ version: SystemVersion) -> some View {
        let result = SystemVersions.result(for: version, trades: trades)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("АКТИВНА")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.green.opacity(0.16)))

                Spacer(minLength: 4)

                if previousVersion != nil {
                    Button {
                        rollbackReason = ""
                        showRollback = true
                        Haptics.tap()
                    } label: {
                        Text("откатить")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("v\(version.version)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(version.change)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Гипотеза: \(version.hypothesis)")
                Text("Метрика: \(version.metric) · срок \(version.checkAfterTrades) сделок")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                resultTile("До", value: result.beforeR, tint: Theme.red)
                resultTile("После", value: result.afterR, tint: Theme.green)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func resultTile(_ title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Text(Fmt.r(value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("История")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Button {
                    showHistory = true
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

            ForEach(Array(historyVersions.prefix(3).enumerated()), id: \.element.persistentModelID) { index, version in
                Button {
                    detail = version
                    Haptics.tap()
                } label: {
                    historyRow(version)
                }
                .buttonStyle(.plain)

                if index < min(historyVersions.count, 3) - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func historyRow(_ version: SystemVersion) -> some View {
        let window = resultInWindow(version)

        return HStack(alignment: .center, spacing: 10) {
            Text("v\(version.version)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.shortDay(version.createdAt))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(version.change)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)

            Text(Fmt.r(window.afterR))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(window.afterR >= 0 ? Theme.green : Theme.red)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    /// Результат версии: сделки от её даты до следующей версии.
    private func resultInWindow(_ version: SystemVersion) -> VersionResult {
        let ascending = SystemVersions.sorted(versions).reversed()
        let nextDate = ascending
            .first { $0.version > version.version }?
            .createdAt ?? Date.distantFuture
        let closed = trades.filter { trade in
            guard trade.result != .open else { return false }
            let date = trade.closedAt ?? trade.entryDate
            return date >= version.createdAt && date < nextDate
        }
        let result = SystemVersions.result(for: version, trades: trades)
        return VersionResult(
            beforeR: result.beforeR,
            afterR: closed.reduce(0) { $0 + $1.actualR },
            tradesAfter: closed.count
        )
    }

    // MARK: - New version

    private var newVersionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Новая версия")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            GlassNoteField(
                placeholder: "Кратко опишите, что изменилось…",
                text: $change,
                limit: 300,
                lines: 2...3,
                minHeight: 52
            )

            GlassNoteField(
                placeholder: "Гипотеза: что должно улучшиться",
                text: $hypothesis,
                limit: 300,
                lines: 1...2,
                minHeight: 44
            )

            GlassNoteField(
                placeholder: "Метрика: чем измеряем",
                text: $metric,
                limit: 200,
                lines: 1...2,
                minHeight: 44
            )

            Stepper(value: $checkAfter, in: 1...200) {
                Text("Срок проверки: \(checkAfter) сделок")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .tint(Theme.accent)

            Button {
                createVersion(
                    change: change,
                    hypothesis: hypothesis,
                    metric: metric,
                    checkAfter: checkAfter,
                    note: ""
                )
            } label: {
                Text("Зафиксировать изменение")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(canSave ? Theme.accent : Theme.accent.opacity(0.3)))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSave)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var noVersionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Базовой версии ещё нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Зафиксируйте первую версию правил: что делаете сейчас, какую гипотезу проверяете и чем измеряете. Дальше каждое изменение станет новой версией.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Rollback

    private var rollbackSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Откат версии")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let previousVersion {
                            Text("Вернуть правила v\(previousVersion.version)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    Spacer(minLength: 8)
                    Button("Закрыть") {
                        showRollback = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }

                GlassNoteField(
                    placeholder: "Причина отката",
                    text: $rollbackReason,
                    limit: 300,
                    lines: 2...3,
                    minHeight: 52
                )

                PrimaryButton(
                    title: "Откатить",
                    isEnabled: !rollbackReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    rollback()
                }
            }
            .padding(22)
        }
    }

    private func createVersion(
        change: String,
        hypothesis: String,
        metric: String,
        checkAfter: Int,
        note: String
    ) {
        for version in versions {
            version.isActive = false
        }
        let created = SystemVersion(
            version: SystemVersions.nextVersion(versions),
            change: change.trimmingCharacters(in: .whitespacesAndNewlines),
            hypothesis: hypothesis.trimmingCharacters(in: .whitespacesAndNewlines),
            metric: metric.trimmingCharacters(in: .whitespacesAndNewlines),
            checkAfterTrades: max(checkAfter, 1),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: true
        )
        context.insert(created)
        try? context.save()
        Haptics.success()
    }

    private func rollback() {
        guard let previousVersion else { return }
        createVersion(
            change: "Возврат к v\(previousVersion.version): \(previousVersion.change)",
            hypothesis: "Вернуть поведение v\(previousVersion.version)",
            metric: previousVersion.metric,
            checkAfter: previousVersion.checkAfterTrades,
            note: rollbackReason
        )
        self.change = ""
        self.hypothesis = ""
        self.metric = ""
        showRollback = false
    }
}

// MARK: - History sheet

private struct VersionHistorySheet: View {
    let versions: [SystemVersion]
    let trades: [Trade]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("История версий")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Старые версии не редактируются.")
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

                VStack(spacing: 0) {
                    ForEach(Array(SystemVersions.sorted(versions).enumerated()), id: \.element.persistentModelID) { index, version in
                        let result = SystemVersions.result(for: version, trades: trades)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("v\(version.version)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                if version.isActive {
                                    Text("АКТИВНА")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(Theme.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Theme.green.opacity(0.16)))
                                }
                                Spacer(minLength: 4)
                                Text(Fmt.shortDay(version.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                            }

                            Text(version.change)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("До \(Fmt.r(result.beforeR)) · после \(Fmt.r(result.afterR))")
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)

                        if index < versions.count - 1 {
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

// MARK: - Detail sheet

private struct VersionDetailSheet: View {
    let version: SystemVersion
    let trades: [Trade]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("v\(version.version)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(Fmt.shortDay(version.createdAt))
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

                VersionBlock(title: "Что изменилось", text: version.change)
                VersionBlock(title: "Гипотеза", text: version.hypothesis)
                VersionBlock(title: "Метрика", text: "\(version.metric) · срок \(version.checkAfterTrades) сделок")
                if !version.note.isEmpty {
                    VersionBlock(title: "Причина записи", text: version.note)
                }

                let result = SystemVersions.result(for: version, trades: trades)
                HStack(spacing: 10) {
                    resultTile("До", result.beforeR, Theme.red)
                    resultTile("После", result.afterR, Theme.green)
                }
            }
            .padding(22)
        }
    }

    private func resultTile(_ title: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Text(Fmt.r(value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

private struct VersionBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Theme.textTertiary)
            Text(text.isEmpty ? "—" : text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

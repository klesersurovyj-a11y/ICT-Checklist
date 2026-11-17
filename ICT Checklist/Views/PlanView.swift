//
//  PlanView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PlanView: View {
    @Bindable var plan: TradePlan

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Trade.entryDate, order: .reverse) private var allTrades: [Trade]
    @Query private var settingsList: [AppSettings]

    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var showDeleteConfirm = false

    private var symbols: [String] {
        let list = settingsList.first?.symbols ?? []
        return list.isEmpty ? ["EURUSD", "GBPUSD", "XAUUSD"] : list
    }

    private var resultTint: Color {
        switch plan.result {
        case .win: return Theme.green
        case .loss: return Theme.red
        case .be: return Theme.orange
        case .skip: return Theme.textSecondary
        case .noTrade: return Theme.accent
        case .pending: return Theme.textSecondary
        }
    }

    private var unlinkedTrades: [Trade] {
        allTrades.filter { $0.plan == nil }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    headerCard
                    statusCard
                    textBlocks
                    checklistCard
                    photosCard
                    tradesCard
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .onChange(of: plan.thesis) { _, _ in touch() }
        .onChange(of: plan.planA) { _, _ in touch() }
        .onChange(of: plan.planB) { _, _ in touch() }
        .onChange(of: plan.adaptation) { _, _ in touch() }
        .onChange(of: plan.note) { _, _ in touch() }
        .onChange(of: plan.title) { _, _ in touch() }
        .onDisappear { save() }
        .alert("Удалить план?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) { deletePlan() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("План и его скриншоты будут удалены. Сделки останутся в журнале.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                save()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "План")
                Text("План дня")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 8)

            Text(readinessText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(plan.isChecklistComplete ? Theme.green : Theme.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        (plan.isChecklistComplete ? Theme.green : Theme.orange).opacity(0.14)
                    )
                )
        }
    }

    private var readinessText: String {
        "\(plan.checkedCount)/\(PlanCheck.allCases.count)"
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Коротко: что за идея", text: $plan.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.sentences)
                .tint(Theme.accent)

            HStack(spacing: 10) {
                DatePicker("", selection: $plan.day, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Theme.accent)

                Text(plan.direction.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill((plan.direction == .long ? Theme.green : Theme.red).opacity(0.9))
                    )

                Spacer(minLength: 8)

                Text(Fmt.shortDay(plan.day))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        Chip(title: symbol, isSelected: plan.symbol == symbol) {
                            plan.symbol = symbol
                            touch()
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack(spacing: 8) {
                Chip(title: "LONG", isSelected: plan.direction == .long, tint: Theme.green) {
                    plan.direction = .long
                    touch()
                    Haptics.select()
                }
                Chip(title: "SHORT", isSelected: plan.direction == .short, tint: Theme.red) {
                    plan.direction = .short
                    touch()
                    Haptics.select()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ИТОГ ПЛАНА")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Theme.textTertiary)

            FlowChips(items: PlanResult.allCases.map(\.rawValue), selected: plan.result.rawValue) { value in
                guard let result = PlanResult(rawValue: value) else { return }
                plan.result = result
                touch()
                Haptics.select()
            } tintFor: { value in
                switch PlanResult(rawValue: value) {
                case .win: return Theme.green
                case .loss: return Theme.red
                case .be: return Theme.orange
                case .noTrade: return Theme.accent
                default: return Theme.textSecondary
                }
            }

            Text(statusHint)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var statusHint: String {
        switch plan.result {
        case .win, .loss, .be:
            return "План дошёл до входа — учитывается в коэффициенте отработки."
        case .skip:
            return "Вход пропущен: сетап не соответствовал системе."
        case .noTrade:
            return "Торгового дня не было — вход не планировался."
        case .pending:
            return "Итог не выставлен: план ещё в работе."
        }
    }

    // MARK: - Text blocks

    private var textBlocks: some View {
        VStack(spacing: 12) {
            PlanTextBlock(title: "Идея / тезис", placeholder: "Что вижу на рынке и почему", text: $plan.thesis)
            PlanTextBlock(title: "План A", placeholder: "Основной сценарий", text: $plan.planA)
            PlanTextBlock(title: "План B", placeholder: "Альтернативный сценарий", text: $plan.planB)
            PlanTextBlock(title: "Адаптация", placeholder: "Как меняю план, если рынок пошёл иначе", text: $plan.adaptation)
            PlanTextBlock(title: "Заметки", placeholder: "Наблюдения, теги, что улучшить", text: $plan.note)
        }
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ЧЕК-ЛИСТ СИСТЕМЫ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                Text(plan.isChecklistComplete ? "Всё по системе" : readinessText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(plan.isChecklistComplete ? Theme.green : Theme.orange)
            }

            VStack(spacing: 8) {
                ForEach(PlanCheck.allCases) { check in
                    checklistRow(check)
                }
            }

            if plan.isChecklistComplete {
                InfoHint(
                    text: "Все пункты отмечены — план соответствует системе. Это учитывается в статистике соблюдения.",
                    tint: Theme.green,
                    icon: "checkmark.seal"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func checklistRow(_ check: PlanCheck) -> some View {
        let isOn = plan.checkedKeys.contains(check)
        return Button {
            plan.toggle(check)
            save()
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOn ? Theme.accent : Color.white.opacity(0.06))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isOn ? .white : Theme.textTertiary)
                }
                Text(check.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(isOn ? .white : Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.12) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent.opacity(0.35) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photos

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("СКРИНШОТЫ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                if !plan.photos.isEmpty {
                    Text("\(plan.photos.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plan.sortedPhotos) { photo in
                        PlanPhotoThumb(data: photo.imageData, size: 84)
                            .contextMenu {
                                Button("Удалить", role: .destructive) {
                                    context.delete(photo)
                                    save()
                                    Haptics.tap()
                                }
                            }
                    }

                    PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 8, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.14),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                )
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 84, height: 84)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                images.append(data)
            }
        }
        guard !images.isEmpty else {
            pickedPhotos = []
            return
        }
        for data in images {
            let photo = PlanPhoto(imageData: data)
            context.insert(photo)
            plan.photos.append(photo)
        }
        touch()
        save()
        pickedPhotos = []
        Haptics.success()
    }

    // MARK: - Trades

    private var tradesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("СДЕЛКИ ПЛАНА")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                Menu {
                    if unlinkedTrades.isEmpty {
                        Text("Нет свободных сделок")
                    } else {
                        ForEach(unlinkedTrades) { trade in
                            Button {
                                trade.plan = plan
                                touch()
                                save()
                                Haptics.tap()
                            } label: {
                                Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.symbol) · \(trade.direction.rawValue)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Прикрепить")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
            }

            if plan.trades.isEmpty {
                Text("Сделки ещё не прикреплены. Прикрепите из журнала или привяжите сделку при закрытии.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(plan.trades) { trade in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(trade.symbol) · \(trade.direction.rawValue)")
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(Fmt.shortDay(trade.tradingDay)) · \(trade.result == .open ? "открыта" : trade.result.rawValue)")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 8)
                            Text(trade.result == .open ? "—" : Fmt.r(trade.actualR))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(trade.result == .open ? Theme.textSecondary : rTint(trade.actualR))
                            Button {
                                trade.plan = nil
                                touch()
                                save()
                                Haptics.tap()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.white.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        if trade.id != plan.trades.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func rTint(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
            Haptics.tap()
        } label: {
            Text("Удалить план")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.red.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func deletePlan() {
        for trade in plan.trades {
            trade.plan = nil
        }
        context.delete(plan)
        try? context.save()
        Haptics.warning()
        dismiss()
    }

    // MARK: - Saving

    private func touch() {
        plan.updatedAt = .now
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - Text block

private struct PlanTextBlock: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...8)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }
}

// MARK: - Chips

private struct FlowChips: View {
    let items: [String]
    let selected: String
    let action: (String) -> Void
    let tintFor: (String) -> Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Chip(
                        title: item,
                        isSelected: selected == item,
                        tint: tintFor(item)
                    ) {
                        action(item)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }
}

// MARK: - Photo thumbnail

struct PlanPhotoThumb: View {
    let data: Data?
    var size: CGFloat = 84

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: data?.count) {
            image = data.flatMap { UIImage(data: $0) }
        }
    }
}

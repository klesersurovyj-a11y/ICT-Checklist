//
//  SettingsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

enum TimeSlot: String, Identifiable {
    case start
    case end

    var id: String { rawValue }

    var title: String {
        self == .start ? "Старт цикла" : "Закрытие терминала"
    }
}

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]

    var body: some View {
        ZStack {
            AppBackground()
            if let settings = settingsList.first {
                SettingsContent(settings: settings, onClose: onClose)
            }
        }
        .task {
            if settingsList.isEmpty {
                context.insert(AppSettings())
                try? context.save()
            }
        }
    }
}

private struct SettingsContent: View {
    @Bindable var settings: AppSettings
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate) private var trades: [Trade]
    @Query(sort: \TradingCycle.day) private var cycles: [TradingCycle]

    @State private var shareItems: [URL] = []
    @State private var showShare = false
    @State private var showExportError = false
    @State private var showNotificationsAlert = false

    @State private var editingTime: TimeSlot?
    @State private var showAdd = false
    @State private var addText = ""
    @State private var showRename = false
    @State private var renameTarget = ""
    @State private var renameText = ""

    private var canDeleteSymbol: Bool {
        settings.symbols.count > 1
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                symbolsCard
                timeCard
                reminderCard
                ladderCard
                dealCard
                dataCard
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(item: $editingTime) { slot in
            TimeWheelSheet(settings: settings, slot: slot)
        }
        .alert("Добавить символ", isPresented: $showAdd) {
            TextField("Например EURUSD", text: $addText)
                .textInputAutocapitalization(.characters)
            Button("Добавить") { addSymbol() }
            Button("Отмена", role: .cancel) { addText = "" }
        } message: {
            Text("Символ появится в чек-листе и журнале.")
        }
        .alert("Переименовать символ", isPresented: $showRename) {
            TextField("Символ", text: $renameText)
                .textInputAutocapitalization(.characters)
            Button("Сохранить") { renameSymbol() }
            Button("Отмена", role: .cancel) { renameText = "" }
        } message: {
            Text("Символ изменится в списке выбора, уже открытые сделки останутся как есть.")
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .alert("Не удалось экспортировать", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Попробуйте ещё раз.")
        }
        .alert("Уведомления выключены", isPresented: $showNotificationsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Разрешите уведомления для приложения в настройках iOS: Настройки → ICT Checklist → Уведомления.")
        }
        .task { rescheduleExistingReminders() }
        .onChange(of: settings.cycleStartHour) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleStartMinute) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleEndHour) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleEndMinute) { _, _ in rescheduleExistingReminders() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Система")
                ScreenTitle(text: "Настройки")
            }
            Spacer(minLength: 4)
            if let onClose {
                Button {
                    onClose()
                    Haptics.tap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Symbols

    private var symbolsCard: some View {
        settingsCard("СИМВОЛЫ") {
            VStack(spacing: 0) {
                ForEach(Array(settings.symbols.enumerated()), id: \.element) { index, symbol in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                    }
                    symbolRow(symbol)
                }
                Divider()
                    .overlay(Color.white.opacity(0.06))
                addSymbolRow
            }
        }
    }

    private func symbolRow(_ symbol: String) -> some View {
        ZStack(alignment: .trailing) {
            Button {
                renameTarget = symbol
                renameText = symbol
                showRename = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    Text(symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer(minLength: 44)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                deleteSymbol(symbol)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.red.opacity(canDeleteSymbol ? 1 : 0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canDeleteSymbol)
        }
    }

    private var addSymbolRow: some View {
        Button {
            addText = ""
            showAdd = true
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.blue)
                        .frame(width: 30, height: 30)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Добавить символ")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.blue)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cycle time

    private var timeCard: some View {
        settingsCard("ВРЕМЯ ЦИКЛА") {
            VStack(spacing: 0) {
                timeRow(
                    "Старт цикла",
                    hour: settings.cycleStartHour,
                    minute: settings.cycleStartMinute,
                    slot: .start
                )
                Divider()
                    .overlay(Color.white.opacity(0.06))
                timeRow(
                    "Закрытие терминала",
                    hour: settings.cycleEndHour,
                    minute: settings.cycleEndMinute,
                    slot: .end
                )
            }
        }
    }

    private func timeRow(_ title: String, hour: Int, minute: Int, slot: TimeSlot) -> some View {
        Button {
            editingTime = slot
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(Fmt.clock(hour: hour, minute: minute))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.orange)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reminders

    private var reminderCard: some View {
        settingsCard("НАПОМИНАНИЯ") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Старт цикла",
                    subtitle: "\(Fmt.clock(hour: settings.cycleStartHour, minute: settings.cycleStartMinute)) — «Старт цикла»",
                    isOn: startReminderBinding
                )
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)
                ToggleRow(
                    title: "Закрытие терминала",
                    subtitle: "\(Fmt.clock(hour: settings.cycleEndHour, minute: settings.cycleEndMinute)) — «Закрыть терминал, перевести в BE»",
                    isOn: endReminderBinding
                )
                Text("Напоминания локальные: работают без сети и не покидают устройство.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    private var startReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.reminderStartEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.reminderStartEnabled = true
                            save()
                            ReminderService.scheduleStart(
                                hour: settings.cycleStartHour,
                                minute: settings.cycleStartMinute
                            )
                            Haptics.success()
                        } else {
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.reminderStartEnabled = false
                    save()
                    ReminderService.cancelStart()
                    Haptics.tap()
                }
            }
        )
    }

    private var endReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.reminderEndEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.reminderEndEnabled = true
                            save()
                            ReminderService.scheduleEnd(
                                hour: settings.cycleEndHour,
                                minute: settings.cycleEndMinute
                            )
                            Haptics.success()
                        } else {
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.reminderEndEnabled = false
                    save()
                    ReminderService.cancelEnd()
                    Haptics.tap()
                }
            }
        )
    }

    private func rescheduleExistingReminders() {
        if settings.reminderStartEnabled {
            ReminderService.scheduleStart(hour: settings.cycleStartHour, minute: settings.cycleStartMinute)
        }
        if settings.reminderEndEnabled {
            ReminderService.scheduleEnd(hour: settings.cycleEndHour, minute: settings.cycleEndMinute)
        }
    }

    // MARK: - Risk ladder

    private var ladderCard: some View {
        settingsCard("СТУПЕНИ РИСКА") {
            VStack(spacing: 0) {
                ladderRow(1, value: $settings.ladder1)
                Divider()
                    .overlay(Color.white.opacity(0.06))
                ladderRow(2, value: $settings.ladder2)
                Divider()
                    .overlay(Color.white.opacity(0.06))
                ladderRow(3, value: $settings.ladder3)
                Divider()
                    .overlay(Color.white.opacity(0.06))
                Text("+2R внутри ступени — переход выше")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    private func ladderRow(_ index: Int, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text("Ступень \(index)")
                .font(.system(size: 17))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            CompactNumberField(value: value, prefix: "$", range: 1...100000, digits: 0)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Deal

    private var dealCard: some View {
        settingsCard("СДЕЛКА") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Минимальный RR")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    CompactNumberField(value: $settings.minRR, range: 1...5, digits: 1, fieldWidth: 118)
                }

                RRSlider(value: $settings.minRR)

                Text("Вход блокируется, если расчётный RR ниже")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Data

    private var dataCard: some View {
        settingsCard("ДАННЫЕ") {
            VStack(spacing: 0) {
                Button {
                    exportCSV()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.blue)
                        Text("Экспорт журнала")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                Text("Два CSV-файла с разделителем «;»: сделки и торговые циклы. Откроется системное меню «Поделиться».")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Данные хранятся только на этом устройстве")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Text("ICT Checklist \(appVersion)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Card container

    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Actions

    private func addSymbol() {
        let value = addText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        addText = ""
        guard !value.isEmpty else { return }
        var list = settings.symbols
        guard !list.contains(value) else { return }
        list.append(value)
        settings.symbols = list
        save()
        Haptics.success()
    }

    private func renameSymbol() {
        let value = renameText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !value.isEmpty else { return }
        var list = settings.symbols
        guard let index = list.firstIndex(of: renameTarget) else { return }
        if value != renameTarget && list.contains(value) { return }
        list[index] = value
        settings.symbols = list
        save()
        Haptics.success()
    }

    private func deleteSymbol(_ symbol: String) {
        guard settings.symbols.count > 1 else { return }
        var list = settings.symbols
        list.removeAll { $0 == symbol }
        settings.symbols = list
        save()
        Haptics.tap()
    }

    private func save() {
        try? context.save()
    }

    private func exportCSV() {
        do {
            shareItems = try CSVExport.writeFiles(trades: trades, cycles: cycles)
            showShare = true
            Haptics.success()
        } catch {
            showExportError = true
            Haptics.warning()
        }
    }
}

// MARK: - Numeric input

private struct CompactNumberField: View {
    @Binding var value: Double
    var prefix: String? = nil
    var range: ClosedRange<Double>? = nil
    var digits: Int = 0
    var fieldWidth: CGFloat = 96

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 1) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .tint(Theme.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: fieldWidth)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { text = format(value) }
        .onChange(of: text) { _, newValue in
            let normalized = newValue.replacingOccurrences(of: ",", with: ".")
            guard let parsed = Double(normalized), parsed > 0 else { return }
            let clamped = range.map { min(max(parsed, $0.lowerBound), $0.upperBound) } ?? parsed
            let factor = pow(10, Double(digits))
            let rounded = (clamped * factor).rounded() / factor
            if rounded != value {
                value = rounded
            }
        }
        .onChange(of: value) { _, newValue in
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            if Double(normalized) != newValue {
                text = format(newValue)
            }
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.\(digits)f", value)
    }
}

// MARK: - RR slider

private struct RRSlider: View {
    @Binding var value: Double

    private let lower: Double = 1
    private let upper: Double = 5
    private let step: Double = 0.1
    private let ticks: [Double] = [1, 2, 3, 4, 5]
    private let inset: CGFloat = 10

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let usable = max(proxy.size.width, 1)
                let fraction = min(max((value - lower) / (upper - lower), 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 4)
                    Capsule()
                        .fill(Theme.blue)
                        .frame(width: usable * fraction, height: 4)
                    ForEach(ticks, id: \.self) { tick in
                        Circle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 5, height: 5)
                            .offset(x: usable * ((tick - lower) / (upper - lower)))
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: Theme.blue.opacity(0.8), radius: 6)
                        .overlay(Circle().strokeBorder(Theme.blue, lineWidth: 1))
                        .offset(x: usable * fraction - 10)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let x = min(max(gesture.location.x, 0), usable)
                            let raw = lower + (x / usable) * (upper - lower)
                            let stepped = (raw / step).rounded() * step
                            let clamped = min(max(stepped, lower), upper)
                            if abs(clamped - value) > 0.0001 {
                                value = clamped
                                Haptics.select()
                            }
                        }
                )
            }
            .frame(height: 24)
            .padding(.horizontal, inset)

            HStack(spacing: 0) {
                ForEach(Array(ticks.enumerated()), id: \.element) { index, tick in
                    Text(String(format: "%.1f", tick))
                        .font(.system(size: 11, weight: abs(tick - value) < 0.05 ? .bold : .regular))
                        .foregroundStyle(abs(tick - value) < 0.05 ? .white : Theme.textTertiary)
                    if index < ticks.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, inset)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Минимальный RR")
        .accessibilityValue(String(format: "%.1f", value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(upper, value + step)
            case .decrement:
                value = max(lower, value - step)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Time wheel

private struct TimeWheelSheet: View {
    let settings: AppSettings
    let slot: TimeSlot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(slot.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    try? context.save()
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.blue)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)

            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                components.hour = slot == .start ? settings.cycleStartHour : settings.cycleEndHour
                components.minute = slot == .start ? settings.cycleStartMinute : settings.cycleEndMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                if slot == .start {
                    settings.cycleStartHour = components.hour ?? 19
                    settings.cycleStartMinute = components.minute ?? 0
                } else {
                    settings.cycleEndHour = components.hour ?? 22
                    settings.cycleEndMinute = components.minute ?? 0
                }
                try? context.save()
            }
        )
    }
}

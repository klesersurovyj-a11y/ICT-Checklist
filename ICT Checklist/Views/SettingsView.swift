//
//  SettingsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import CoreData
import UniformTypeIdentifiers

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
    @Query(sort: \TradingCycle.createdAt) private var cycles: [TradingCycle]
    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]
    @Query private var errorNotes: [ErrorNote]
    @Query private var brainNotes: [BrainNote]
    @Query private var journalEntries: [JournalEntry]
    @Query private var weekPlans: [WeekPlan]

    @State private var showAccounts = false
    @State private var showSystem = false
    @State private var showProfiles = false
    @State private var showAssistant = false
    @State private var showMarketBehavior = false
    @State private var showAlgorithmMonitor = false
    @State private var showRiskIntelligence = false

    @State private var showExportError = false
    @State private var showNotificationsAlert = false
    @State private var priceProbe: String?
    @State private var isProbing = false

    @State private var editingTime: TimeSlot?
    @State private var showAdd = false
    @State private var addText = ""
    @State private var showRename = false
    @State private var renameTarget = ""
    @State private var renameText = ""

    @State private var showBackupImporter = false
    @State private var showBackupAlert = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""
    @State private var showDemoRemoveAlert = false
    @State private var showAppLockAlert = false

    @AppStorage("appLock.enabled") private var appLockEnabled = false
    @State private var assistantKeys: [String: Bool] = [:]

    private var canDeleteSymbol: Bool {
        settings.symbols.count > 1
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                systemCard
                profilesCard
                assistantCard
                marketBehaviorCard
                algorithmMonitorCard
                riskIntelligenceCard
                symbolsCard
                timeCard
                reminderCard
                ladderCard
                dealCard
                dailyLimitsCard
                weeklyLimitsCard
                marketCard
                accountsCard
                dataCard
                backupCard
                if demoCount > 0 {
                    demoCard
                }
                securityCard
                syncCard
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
        .fullScreenCover(isPresented: $showAccounts) {
            AccountsView()
        }
        .fullScreenCover(isPresented: $showSystem) {
            SystemView()
        }
        .fullScreenCover(isPresented: $showProfiles) {
            ProfilesView()
        }
        .fullScreenCover(isPresented: $showAssistant) {
            AssistantView()
        }
        .fullScreenCover(isPresented: $showMarketBehavior) {
            MarketBehaviorView()
        }
        .fullScreenCover(isPresented: $showAlgorithmMonitor) {
            AlgorithmMonitorView()
        }
        .fullScreenCover(isPresented: $showRiskIntelligence) {
            RiskIntelligenceView()
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
        .alert(backupAlertTitle, isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupAlertMessage)
        }
        .alert("Удалить демо-данные?", isPresented: $showDemoRemoveAlert) {
            Button("Удалить", role: .destructive) {
                DemoData.remove(context: context)
                Haptics.warning()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Исчезнут примерные сделки, планы и заметки, загруженные демо-базой. Ваши собственные записи останутся.")
        }
        .alert("Замок включён", isPresented: $showAppLockAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Данные остаются на этом устройстве. Замок защищает только доступ к приложению: при следующем запуске или возврате из фона понадобится Face ID, Touch ID или код-пароль устройства.")
        }
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    restoreBackup(from: url)
                }
            case .failure:
                showBackupAlert(
                    title: "Не удалось открыть файл",
                    message: "Выберите JSON-файл резервной копии ICT Checklist."
                )
                Haptics.warning()
            }
        }
        .task {
            refreshAssistantKeys()
            rescheduleExistingReminders()
        }
        .onChange(of: settings.assistantProviderRaw) { _, _ in
            refreshAssistantKeys()
        }
        .onChange(of: settings.cycleStartHour) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleStartMinute) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleEndHour) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.cycleEndMinute) { _, _ in rescheduleExistingReminders() }
        .onChange(of: settings.ladder1) { _, _ in refreshWidgetSnapshot() }
        .onChange(of: settings.ladder2) { _, _ in refreshWidgetSnapshot() }
        .onChange(of: settings.ladder3) { _, _ in refreshWidgetSnapshot() }
        .onChange(of: settings.dailyLimitsEnabled) { _, _ in refreshWidgetSnapshot() }
        .onChange(of: settings.maxDailyLossR) { _, _ in refreshWidgetSnapshot() }
        .onChange(of: settings.maxTradesPerDay) { _, _ in refreshWidgetSnapshot() }
    }

    private func refreshWidgetSnapshot() {
        LadderEngine.sync(context: context)
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
                        .foregroundStyle(.black)
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
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)
                ToggleRow(
                    title: "Напоминать о цели",
                    subtitle: "Когда суммарный R месяца дойдёт до цели",
                    isOn: goalReminderBinding
                )
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)
                ToggleRow(
                    title: "Напомнить про дневник",
                    subtitle: "Через 15 минут после закрытия терминала, если записи за день нет",
                    isOn: journalReminderBinding
                )
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)
                ToggleRow(
                    title: "Напоминать о лимите дня",
                    subtitle: "Когда достигнут лимит по сделкам или по R",
                    isOn: dailyLimitReminderBinding
                )
                .disabled(!settings.dailyLimitsEnabled)
                .opacity(settings.dailyLimitsEnabled ? 1 : 0.45)
                if !settings.dailyLimitsEnabled {
                    Text("Включите «Лимиты дня», чтобы напоминание работало.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                ToggleRow(
                    title: "Напомнить про план недели",
                    subtitle: "В воскресенье в 18:00, если план новой недели ещё не заполнен",
                    isOn: weekPlanReminderBinding
                )
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)
                ToggleRow(
                    title: "Напоминать о разборе",
                    subtitle: "Через час после закрытия сделки, если разбор ещё не заполнен",
                    isOn: reviewReminderBinding
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

    private var goalReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.goalReminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.goalReminderEnabled = true
                            save()
                            Haptics.success()
                        } else {
                            settings.goalReminderEnabled = false
                            save()
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.goalReminderEnabled = false
                    save()
                    Haptics.tap()
                }
            }
        )
    }

    private var reviewReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.reviewReminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.reviewReminderEnabled = true
                            save()
                            TradeReviewReminder.refresh(context: context)
                            Haptics.success()
                        } else {
                            settings.reviewReminderEnabled = false
                            save()
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.reviewReminderEnabled = false
                    save()
                    TradeReviewReminder.refresh(context: context)
                    Haptics.tap()
                }
            }
        )
    }

    private var journalReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.journalReminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.journalReminderEnabled = true
                            save()
                            JournalReminder.refresh(context: context)
                            Haptics.success()
                        } else {
                            settings.journalReminderEnabled = false
                            save()
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.journalReminderEnabled = false
                    save()
                    JournalReminder.refresh(context: context)
                    Haptics.tap()
                }
            }
        )
    }

    private var dailyLimitReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.dailyLimitReminderEnabled },
            set: { enabled in
                guard settings.dailyLimitsEnabled else { return }
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.dailyLimitReminderEnabled = true
                            save()
                            Haptics.success()
                        } else {
                            settings.dailyLimitReminderEnabled = false
                            save()
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.dailyLimitReminderEnabled = false
                    save()
                    Haptics.tap()
                }
            }
        )
    }

    private var weekPlanReminderBinding: Binding<Bool> {
        Binding(
            get: { settings.weekPlanReminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        if granted {
                            settings.weekPlanReminderEnabled = true
                            save()
                            WeekPlanReminder.refresh(context: context)
                            Haptics.success()
                        } else {
                            settings.weekPlanReminderEnabled = false
                            save()
                            showNotificationsAlert = true
                            Haptics.warning()
                        }
                    }
                } else {
                    settings.weekPlanReminderEnabled = false
                    save()
                    WeekPlanReminder.refresh(context: context)
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
        JournalReminder.refresh(context: context)
    }

    // MARK: - System

    private var systemCard: some View {
        settingsCard("СИСТЕМА") {
            Button {
                showSystem = true
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Конструктор торговой системы")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text("TDA + Risk · этапы, риск, лимиты")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Profiles

    private var profilesCard: some View {
        settingsCard("ПРОФИЛИ") {
            Button {
                showProfiles = true
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "person.2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("База профилей")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text("Трейдеры, их системы и риск")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Assistant

    private var assistantCard: some View {
        settingsCard("ИИ-АССИСТЕНТ") {
            VStack(spacing: 0) {
                Button {
                    showAssistant = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Разбор сделок и системы")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Text("TDA + Risk · стиль AlexxxFX и Mordan")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 8) {
                    Text("ПРОВАЙДЕР")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)

                    GlassSegmented(
                        options: AssistantProvider.allCases,
                        selection: providerBinding,
                        label: { $0.title }
                    )

                    Text(settings.assistantProvider.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                assistantModelRow

                Divider()
                    .overlay(Color.white.opacity(0.06))

                assistantKeyRow

                Text("Ключ каждого провайдера хранится отдельно. При ошибке квоты ассистент предложит переключиться на второго — история чата сохранится.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    private var providerBinding: Binding<AssistantProvider> {
        Binding(
            get: { settings.assistantProvider },
            set: { next in
                guard next != settings.assistantProvider else { return }
                settings.assistantProvider = next
                settings.assistantModelName = next.defaultModel
                save()
                Haptics.select()
            }
        )
    }

    private var assistantModelRow: some View {
        Menu {
            ForEach(settings.assistantProvider.models, id: \.self) { name in
                Button {
                    settings.assistantModelName = name
                    save()
                    Haptics.select()
                } label: {
                    if name == settings.assistantModelName {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Модель")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Text(settings.assistantModelName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
    }

    private var assistantKeyRow: some View {
        let provider = settings.assistantProvider
        let hasKey = assistantKeys[provider.keyName] ?? false

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ключ \(provider.keyName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(hasKey ? "добавлен" : "не добавлен")
                    .font(.system(size: 11.5))
                    .foregroundStyle(hasKey ? Theme.green : Theme.orange)
            }

            Spacer(minLength: 8)

            Link(destination: provider.keyURL) {
                Text("Где взять")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Market behavior

    private var marketBehaviorCard: some View {
        settingsCard("MARKET BEHAVIOR") {
            Button {
                showMarketBehavior = true
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Market Behavior Analyzer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text("Структура · сессии · дни · инструменты · POI")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Algorithm monitor

    private var algorithmMonitorCard: some View {
        settingsCard("ALGORITHM MONITOR") {
            Button {
                showAlgorithmMonitor = true
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Algorithm Monitor")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text("Скользящие метрики и сигнал ухудшения")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Risk intelligence

    private var riskIntelligenceCard: some View {
        settingsCard("RISK INTELLIGENCE") {
            Button {
                showRiskIntelligence = true
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Risk Intelligence")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text("Риск, просадка, лимиты и лестница")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
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

                Divider()
                    .overlay(Color.white.opacity(0.06))

                HStack(spacing: 8) {
                    Text("Риск на сделку")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        CompactNumberField(
                            value: $settings.maxRiskPercent,
                            range: 0.1...20,
                            digits: 1,
                            fieldWidth: 74
                        )
                        Text("%")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text("Risk Intelligence предупредит, если фактический риск сделки выше этого процента капитала")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Daily limits

    private var dailyLimitsCard: some View {
        settingsCard("ЛИМИТЫ ДНЯ") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Включить лимиты",
                    subtitle: "Новых входов нет, пока не начнётся следующий цикл",
                    isOn: $settings.dailyLimitsEnabled
                )

                if settings.dailyLimitsEnabled {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.vertical, 8)

                    HStack(spacing: 8) {
                        Text("Максимальный убыток")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        CompactNumberField(
                            value: $settings.maxDailyLossR,
                            prefix: "\u{2212}",
                            range: 0.5...10,
                            digits: 1,
                            fieldWidth: 118
                        )
                    }
                    .padding(.vertical, 9)

                    Divider()
                        .overlay(Color.white.opacity(0.06))

                    maxTradesRow

                    Text("Достигнутый лимит блокирует новые входы до старта следующего цикла. Открытые позиции не затрагиваются.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
            }
        }
    }

    private var maxTradesRow: some View {
        HStack(spacing: 8) {
            Text("Сделок за день")
                .font(.system(size: 17))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                Button {
                    settings.maxTradesPerDay = max(settings.maxTradesPerDay - 1, 1)
                    save()
                    Haptics.select()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(settings.maxTradesPerDay <= 1 ? Theme.textTertiary : .white)
                        .frame(width: 30, height: 30)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(settings.maxTradesPerDay <= 1)

                Text("\(settings.maxTradesPerDay)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 20)

                Button {
                    settings.maxTradesPerDay = min(settings.maxTradesPerDay + 1, 10)
                    save()
                    Haptics.select()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.accent.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .disabled(settings.maxTradesPerDay >= 10)
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: - Weekly limits

    private var weeklyLimitsCard: some View {
        settingsCard("ЛИМИТЫ НЕДЕЛИ") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Включить недельные лимиты",
                    subtitle: "Предупреждение в Risk Intelligence",
                    isOn: $settings.weeklyLimitsEnabled
                )

                if settings.weeklyLimitsEnabled {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.vertical, 8)

                    HStack(spacing: 8) {
                        Text("Максимальный убыток")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        CompactNumberField(
                            value: $settings.maxWeeklyLossR,
                            prefix: "\u{2212}",
                            range: 2...40,
                            digits: 1,
                            fieldWidth: 118
                        )
                    }
                    .padding(.vertical, 9)

                    Divider()
                        .overlay(Color.white.opacity(0.06))

                    maxTradesWeekRow

                    Text("Неделя начинается с понедельника. Достигнутый лимит не блокирует входы, но даёт предупреждение в Risk Intelligence.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
            }
        }
    }

    private var maxTradesWeekRow: some View {
        HStack(spacing: 8) {
            Text("Сделок за неделю")
                .font(.system(size: 17))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                Button {
                    settings.maxTradesPerWeek = max(settings.maxTradesPerWeek - 1, 1)
                    save()
                    Haptics.select()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(settings.maxTradesPerWeek <= 1 ? Theme.textTertiary : .white)
                        .frame(width: 30, height: 30)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(settings.maxTradesPerWeek <= 1)

                Text("\(settings.maxTradesPerWeek)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 20)

                Button {
                    settings.maxTradesPerWeek = min(settings.maxTradesPerWeek + 1, 30)
                    save()
                    Haptics.select()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.accent.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .disabled(settings.maxTradesPerWeek >= 30)
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: - Market

    private var marketCard: some View {
        settingsCard("РЫНОК") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Закрывать по TP/SL автоматически",
                    subtitle: "По цене рынка, пока приложение открыто",
                    isOn: autoCloseBinding
                )

                Divider()
                    .overlay(Theme.hairline)
                    .padding(.vertical, 8)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ключ Twelve Data")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(keyIsSet ? "Добавлен · живые цены доступны" : "Не добавлен · цены недоступны")
                            .font(.system(size: 11.5))
                            .foregroundStyle(keyIsSet ? Theme.green : Theme.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 8)
                    Button {
                        probePrice()
                    } label: {
                        HStack(spacing: 6) {
                            if isProbing {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(Theme.background)
                            }
                            Text("Проверить")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accent.opacity(isProbing ? 0.6 : 1)))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(isProbing)
                }
                .padding(.bottom, 8)

                if let priceProbe {
                    Text(priceProbe)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                }

                Divider()
                    .overlay(Theme.hairline)
                    .padding(.bottom, 8)

                Text("Цены приходят с Twelve Data по ключу TWELVE_DATA_API_KEY. TradingView не даёт API для приложений, поэтому цена — от этого сервиса. Ручное закрытие по-прежнему работает, автозакрытие можно выключить в любой момент.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var keyIsSet: Bool {
        ApiKeyManager.shared.has(key: "TWELVE_DATA_API_KEY")
    }

    private func probePrice() {
        guard let symbol = settings.symbols.first else { return }
        isProbing = true
        priceProbe = nil

        Task {
            await PriceBook.shared.refresh(symbols: [symbol.uppercased()], force: true)
            isProbing = false

            if let quote = PriceBook.shared.quote(for: symbol) {
                priceProbe = "\(symbol) · \(Fmt.price(quote.price)) · обновлено \(Fmt.time(quote.updatedAt))"
                Haptics.success()
            } else {
                priceProbe = PriceBook.shared.lastError ?? "Нет ответа от сервиса цен"
                Haptics.warning()
            }
        }
    }

    private var autoCloseBinding: Binding<Bool> {
        Binding(
            get: { settings.autoCloseEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await ReminderService.requestAuthorization()
                        settings.autoCloseEnabled = true
                        save()
                        if !granted {
                            showNotificationsAlert = true
                        }
                        Haptics.success()
                    }
                } else {
                    settings.autoCloseEnabled = false
                    save()
                    Haptics.tap()
                }
            }
        )
    }

    // MARK: - Accounts

    private var accountsCard: some View {
        settingsCard("СЧЕТА И ВЫПЛАТЫ") {
            VStack(spacing: 0) {
                if accounts.isEmpty {
                    Text("Добавьте личный счёт, prop-счёт или демо и записывайте выплаты и выводы средств.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 6)
                } else {
                    ForEach(accounts) { account in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(account.type.rawValue + " · " + moneySummary(account))
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            Spacer(minLength: 8)
                            Text("\(account.operations.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Button {
                    showAccounts = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Открыть счета")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func moneySummary(_ account: TradingAccount) -> String {
        func value(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = amount == amount.rounded() ? 0 : 2
            return formatter.string(from: NSNumber(value: amount)) ?? "0"
        }

        return "выплаты \(value(account.payoutTotal)) \(account.currency) · выводы \(value(account.withdrawalTotal)) \(account.currency)"
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

    // MARK: - Backup

    private var backupCard: some View {
        settingsCard("РЕЗЕРВНАЯ КОПИЯ") {
            VStack(spacing: 0) {
                Button {
                    saveBackup()
                } label: {
                    backupRow(icon: "square.and.arrow.up", title: "Сохранить копию")
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                Button {
                    showBackupImporter = true
                    Haptics.tap()
                } label: {
                    backupRow(icon: "square.and.arrow.down", title: "Восстановить")
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                Text("Один JSON-файл: циклы, ключевые уровни, сделки, метки, скриншоты и настройки. Импорт не удаляет текущие данные и пропускает записи, которые уже есть.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    private func backupRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
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

    // MARK: - Demo data

    private var demoCount: Int {
        trades.filter { $0.isDemo }.count
            + brainNotes.filter { $0.isDemo }.count
            + accounts.filter { $0.isDemo }.count
    }

    private var demoCard: some View {
        settingsCard("ДЕМО-ДАННЫЕ") {
            VStack(spacing: 0) {
                Button {
                    showDemoRemoveAlert = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.red)
                        Text("Удалить демо-данные")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Text("\(demoCount)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                Text("Удаляются только записи, загруженные демо-базой при первом запуске. Свои сделки, планы и заметки остаются на месте.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Security

    private var securityCard: some View {
        settingsCard("БЕЗОПАСНОСТЬ") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Замок приложения",
                    subtitle: "Face ID, Touch ID или код-пароль при запуске и возврате из фона",
                    isOn: appLockBinding
                )

                Text("Данные остаются на этом устройстве. Замок защищает только доступ к приложению: он не шифрует базу.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { value in
                appLockEnabled = value
                AppLock.shared.setEnabled(value)
                if value {
                    showAppLockAlert = true
                }
            }
        )
    }

    // MARK: - Storage

    private var syncCard: some View {
        settingsCard("ХРАНЕНИЕ") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: "internaldrive")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Только это устройство")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Без облака и синхронизации")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.vertical, 12)

                Divider()
                    .overlay(Theme.hairline)

                Text("Циклы, сделки, скриншоты и настройки хранятся в базе на этом устройстве.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                Text("Резервную копию можно выгрузить в JSON и сохранить в «Файлы».")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Данные хранятся на этом устройстве")
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
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
        CycleActivityController.shared.sync(context: context)
    }

    private func refreshAssistantKeys() {
        var result: [String: Bool] = [:]
        for provider in AssistantProvider.allCases {
            result[provider.keyName] = ApiKeyManager.shared.has(key: provider.keyName)
        }
        assistantKeys = result
    }

    private func exportCSV() {
        do {
            let files = try CSVExport.writeFiles(trades: trades, cycles: cycles)
            SharePresenter.share(files)
            Haptics.success()
        } catch {
            showExportError = true
            Haptics.warning()
        }
    }

    private func saveBackup() {
        do {
            let url = try BackupStore.writeFile(
                cycles: cycles,
                trades: trades,
                settings: settings,
                accounts: accounts,
                errors: errorNotes,
                brain: brainNotes,
                journal: journalEntries,
                weeks: weekPlans
            )
            SharePresenter.share([url])
            Haptics.success()
        } catch {
            showBackupAlert(
                title: "Не удалось сохранить копию",
                message: "Попробуйте ещё раз."
            )
            Haptics.warning()
        }
    }

    private func restoreBackup(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let result = try BackupStore.restore(from: data, context: context)
            LadderEngine.sync(context: context)

            backupAlertTitle = "Копия восстановлена"
            backupAlertMessage = restoreSummary(result)
            showBackupAlert = true
            Haptics.success()
        } catch {
            showBackupAlert(
                title: "Не удалось восстановить",
                message: "Файл не подходит или повреждён."
            )
            Haptics.warning()
        }
    }

    private func showBackupAlert(title: String, message: String) {
        backupAlertTitle = title
        backupAlertMessage = message
        showBackupAlert = true
    }

    private func restoreSummary(_ result: BackupStore.RestoreResult) -> String {
        var lines = [
            "Восстановлено: \(Fmt.deals(result.trades)) · \(Fmt.tradingDays(result.cycles))."
        ]
        if result.errors > 0 {
            lines.append("Ошибок: \(result.errors).")
        }
        if result.skippedTrades > 0 || result.skippedCycles > 0 {
            lines.append(
                "Пропущено как уже существующее: \(Fmt.deals(result.skippedTrades)) · \(Fmt.tradingDays(result.skippedCycles))."
            )
        }
        return lines.joined(separator: "\n")
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

//
//  AssistantView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct AssistantView: View {
    var prefill: String? = nil
    var focusMessage: AssistantMessage? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AssistantMessage.createdAt) private var messages: [AssistantMessage]
    @Query private var settingsList: [AppSettings]

    @AppStorage("assistant.lastCost") private var lastCost: Double = 0
    @AppStorage("assistant.lastCostProvider") private var lastCostProvider = ""

    @State private var input = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @State private var showBilling = false
    @State private var quotaProvider: AssistantProvider?
    @State private var failedPrompt: String?
    @State private var failedHistory: [AssistantTurn] = []
    @State private var failedSystem: String?
    @State private var snapshotText = ""
    @State private var tradeCount = 0
    @State private var planCount = 0
    @State private var systemName = "TDA + Risk"
    @State private var hasKey = true

    private let quickPrompts = [
        "Разбери мои последние сделки",
        "Где я нарушаю систему",
        "Что исправить в риск-менеджменте",
        "Собери план на неделю"
    ]

    private var settings: AppSettings? { settingsList.first }

    private var provider: AssistantProvider {
        settings?.assistantProvider ?? .openAI
    }

    private var model: String {
        let value = settings?.assistantModelName ?? provider.defaultModel
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        topBar
                            .padding(.top, 8)
                        contextRow
                        modelRow

                        if !hasKey {
                            keyCard
                        }

                        if messages.isEmpty {
                            greetingCard
                        } else {
                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.persistentModelID)
                            }
                        }

                        if isThinking {
                            thinkingRow
                        }

                        if let errorText {
                            errorCard(errorText)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .onChange(of: messages.count) { _, _ in scroll(proxy) }
                .onChange(of: isThinking) { _, _ in scroll(proxy) }
                .task(id: focusMessage?.persistentModelID) {
                    guard let focusMessage else { return }
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(focusMessage.persistentModelID, anchor: .center)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .task { refreshContext() }
            .onChange(of: settingsList.first?.assistantProviderRaw) { _, _ in
                refreshKey()
            }
            .onAppear {
                if let prefill, input.isEmpty {
                    input = prefill
                }
            }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 10) {
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

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Ассистент")
                ScreenTitle(text: "ИИ-ассистент")
            }

            Spacer(minLength: 8)

            if !messages.isEmpty {
                Button {
                    clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var contextRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
            Text("Контекст: \(tradeCount) сделок · \(planCount) планов · \(systemName)")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button {
                refreshContext()
                Haptics.select()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.textTertiary)
    }

    private var modelRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)

            Text("\(provider.title) · \(model)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            if lastCost > 0, lastCostProvider == provider.rawValue {
                Text(costText(lastCost))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 12)
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoHint(
                text: "Для ответов нужен ключ \(provider.title). Его значение вводится в настройках ключей приложения — ассистент читает его как \(provider.keyName).",
                tint: Theme.orange,
                icon: "key"
            )

            Link(destination: provider.keyURL) {
                HStack(spacing: 6) {
                    Text("Где взять ключ \(provider.title)")
                        .font(.system(size: 12.5, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.accent)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text("Ассистент знает твою базу")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Сделки, планы, риск-модель, конструктор системы и записи Second Brain. Разбирает по костяку TDA + Risk и стилю AlexxxFX / Mordan.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(quickPrompts, id: \.self) { prompt in
                Button {
                    send(prompt)
                } label: {
                    HStack(spacing: 6) {
                        Text(prompt)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.red)
                .fixedSize(horizontal: false, vertical: true)

            if quotaProvider != nil {
                Button {
                    switchToOtherProvider()
                } label: {
                    HStack(spacing: 6) {
                        Text("Переключиться на \(provider.other.title)")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressableButtonStyle())
            }

            if showBilling {
                Link(destination: provider.billingURL) {
                    HStack(spacing: 6) {
                        Text("Открыть баланс \(provider.title)")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func bubble(_ message: AssistantMessage) -> some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
        } else {
            Text(LocalizedStringKey(message.text))
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 18)
        }
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Theme.textSecondary)
            Text("Думаю…")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Спросить ассистента", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? Theme.background : Theme.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? Theme.accent : Color.white.opacity(0.07)))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.5)
                }
        }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking && hasKey
    }

    // MARK: - Actions

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func refreshContext() {
        refreshKey()
        let snapshot = AssistantContext.build(context: context)
        snapshotText = snapshot.text
        tradeCount = snapshot.tradeCount
        planCount = snapshot.planCount
        systemName = snapshot.systemName
    }

    private func refreshKey() {
        hasKey = ApiKeyManager.shared.has(key: provider.keyName)
    }

    private func costText(_ value: Double) -> String {
        guard value >= 0.0001 else { return "ответ < $0.0001" }
        return String(format: "ответ $%.4f", value)
    }

    private func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }

        refreshKey()

        guard hasKey else {
            errorText = "Добавьте ключ \(provider.keyName), чтобы ассистент мог отвечать."
            Haptics.warning()
            return
        }

        let history = messages.suffix(12).map { AssistantTurn(role: $0.role, text: $0.text) }
        let systemMessage = StyleKnowledge.systemPrompt + "\n\n" + snapshotText

        context.insert(AssistantMessage(role: "user", text: prompt))
        try? context.save()

        input = ""
        failedPrompt = nil
        failedHistory = []
        failedSystem = nil

        startReply(prompt: prompt, history: history, system: systemMessage)
    }

    private func startReply(prompt: String, history: [AssistantTurn], system: String) {
        errorText = nil
        showBilling = false
        quotaProvider = nil
        isThinking = true
        Haptics.tap()

        let usedProvider = provider
        let usedModel = model

        Task { @MainActor in
            do {
                let reply = try await AssistantService.reply(
                    provider: usedProvider,
                    model: usedModel,
                    system: system,
                    history: history,
                    prompt: prompt
                )
                context.insert(AssistantMessage(role: "assistant", text: reply.text))
                try? context.save()

                lastCost = reply.cost ?? 0
                lastCostProvider = reply.provider.rawValue
                failedPrompt = nil
                failedHistory = []
                failedSystem = nil

                Haptics.success()
            } catch {
                let assistantError = error as? AssistantError
                showBilling = assistantError?.needsBilling ?? false
                quotaProvider = assistantError?.quotaProvider
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? "Не удалось получить ответ."

                if assistantError?.quotaProvider != nil {
                    failedPrompt = prompt
                    failedHistory = history
                    failedSystem = system
                }

                Haptics.warning()
            }

            isThinking = false
            refreshKey()
        }
    }

    /// Переключает провайдера, сохраняя чат, и повторяет последний запрос.
    private func switchToOtherProvider() {
        guard let settings else { return }

        let next = provider.other
        settings.assistantProvider = next
        settings.assistantModelName = next.defaultModel
        try? context.save()

        refreshKey()
        errorText = nil
        showBilling = false
        quotaProvider = nil

        Haptics.select()

        guard hasKey else {
            errorText = "Провайдер переключён на \(next.title). Добавьте ключ \(next.keyName), чтобы продолжить."
            return
        }

        guard let prompt = failedPrompt, let system = failedSystem else { return }

        let history = failedHistory
        failedPrompt = nil
        failedHistory = []
        failedSystem = nil

        startReply(prompt: prompt, history: history, system: system)
    }

    private func clear() {
        for message in messages {
            context.delete(message)
        }
        try? context.save()
        errorText = nil
        showBilling = false
        quotaProvider = nil
        failedPrompt = nil
        failedHistory = []
        failedSystem = nil
        Haptics.warning()
    }
}

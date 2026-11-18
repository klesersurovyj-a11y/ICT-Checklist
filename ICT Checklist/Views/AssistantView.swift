//
//  AssistantView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct AssistantView: View {
    var prefill: String? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AssistantMessage.createdAt) private var messages: [AssistantMessage]

    @State private var input = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @State private var showBilling = false
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

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        topBar
                            .padding(.top, 8)
                        contextRow

                        if !hasKey {
                            keyCard
                        }

                        if messages.isEmpty {
                            greetingCard
                        } else {
                            ForEach(messages) { message in
                                bubble(message)
                            }
                        }

                        if isThinking {
                            thinkingRow
                        }

                        if let errorText {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(errorText)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.red)
                                    .fixedSize(horizontal: false, vertical: true)

                                if showBilling {
                                    Link(destination: AssistantService.billingURL) {
                                        HStack(spacing: 6) {
                                            Text("Открыть баланс OpenAI")
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
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .task { refreshContext() }
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

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            InfoHint(
                text: "Для ответов нужен ключ OpenAI. Его значение вводится в настройках ключей приложения — ассистент читает его как OPENAI_API_KEY.",
                tint: Theme.orange,
                icon: "key"
            )
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
        hasKey = ApiKeyManager.shared.has(key: "OPENAI_API_KEY")
        let snapshot = AssistantContext.build(context: context)
        snapshotText = snapshot.text
        tradeCount = snapshot.tradeCount
        planCount = snapshot.planCount
        systemName = snapshot.systemName
    }

    private func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }

        guard hasKey else {
            errorText = "Добавьте ключ OPENAI_API_KEY, чтобы ассистент мог отвечать."
            Haptics.warning()
            return
        }

        let history = messages.suffix(12).map { AssistantTurn(role: $0.role, text: $0.text) }
        let systemMessage = StyleKnowledge.systemPrompt + "\n\n" + snapshotText

        context.insert(AssistantMessage(role: "user", text: prompt))
        try? context.save()

        input = ""
        errorText = nil
        showBilling = false
        isThinking = true
        Haptics.tap()

        Task { @MainActor in
            do {
                let answer = try await AssistantService.reply(
                    system: systemMessage,
                    history: history,
                    prompt: prompt
                )
                context.insert(AssistantMessage(role: "assistant", text: answer))
                try? context.save()
                Haptics.success()
            } catch {
                let assistantError = error as? AssistantError
                showBilling = assistantError?.needsBilling ?? false
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? "Не удалось получить ответ."
                Haptics.warning()
            }
            isThinking = false
        }
    }

    private func clear() {
        for message in messages {
            context.delete(message)
        }
        try? context.save()
        errorText = nil
        showBilling = false
        Haptics.warning()
    }
}

//
//  OnboardingView.swift
//  ICT Checklist
//
//  Первый запуск: три коротких экрана о цикле, сделках и результате,
//  затем предложение загрузить демо-базу.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("onboarding.completed") private var completed = false

    @State private var page = 0
    @State private var loadDemo = true

    private var pages: [OnboardingPage] { OnboardingPage.all }

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            AppBackground()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        pageContent
                            .padding(.top, 34)

                        Spacer(minLength: 16)

                        if isLastPage {
                            demoCard
                                .padding(.bottom, 14)
                                .transition(.opacity)
                        }

                        primaryButton
                            .padding(.top, isLastPage ? 2 : 18)

                        skipButton

                        dots
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - Page

    private var pageContent: some View {
        VStack(spacing: 0) {
            card
            rows
        }
        .id(page)
        .transition(.opacity)
    }

    private var card: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Image(systemName: pages[page].icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.white)
            }

            Text(pages[page].title)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(pages[page].subtitle)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .glassCard(cornerRadius: 30)
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(Array(pages[page].steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, step: step, isLast: index == pages[page].steps.count - 1)
            }
        }
        .padding(.top, 14)
    }

    private func stepRow(index: Int, step: OnboardingStep, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(step.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            statusView(step.status)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 22)
        .overlay(alignment: .bottomLeading) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 14)
                    .offset(x: 32, y: 9)
            }
        }
    }

    @ViewBuilder
    private func statusView(_ status: OnboardingStepStatus) -> some View {
        switch status {
        case .done:
            ZStack {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .pending:
            Circle()
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1.5)
                .frame(width: 24, height: 24)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Demo

    private var demoCard: some View {
        Button {
            loadDemo.toggle()
            Haptics.select()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Загрузить демо-базу")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(DemoData.tradeCount) сделок, \(DemoData.planCount) плана и \(DemoData.noteCount) заметок Second Brain")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Capsule()
                    .fill(loadDemo ? Color.white : Color.white.opacity(0.14))
                    .frame(width: 46, height: 28)
                    .overlay(alignment: loadDemo ? .trailing : .leading) {
                        Circle()
                            .fill(loadDemo ? Color.black : Color.white.opacity(0.8))
                            .frame(width: 22, height: 22)
                            .padding(3)
                    }
            }
            .padding(12)
            .glassCard(cornerRadius: 18, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            Text(isLastPage ? (loadDemo ? "Начать с демо" : "Начать") : "Дальше")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var skipButton: some View {
        Button {
            finish(loadDemo: false)
        } label: {
            Text("Пропустить")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var dots: some View {
        HStack(spacing: 14) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.white : Color.white.opacity(0.22))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 8)
        .animation(Theme.snappy, value: page)
    }

    // MARK: - Actions

    private func advance() {
        if !isLastPage {
            Haptics.tap()
            withAnimation(Theme.smooth) {
                page += 1
            }
            return
        }

        finish(loadDemo: loadDemo)
    }

    private func finish(loadDemo: Bool) {
        if loadDemo {
            DemoData.seed(context: context)
            Haptics.success()
        } else {
            Haptics.tap()
        }

        completed = true
    }
}

// MARK: - Content

private struct OnboardingStep {
    let title: String
    let status: OnboardingStepStatus
}

private enum OnboardingStepStatus {
    case done
    case pending
    case symbol(String)
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let steps: [OnboardingStep]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            icon: "sun.max",
            title: "Один день — один цикл",
            subtitle: "От новостей и риска до входа и разбора — по шагам, без спешки",
            steps: [
                OnboardingStep(title: "Утро: контекст и риск", status: .done),
                OnboardingStep(title: "Вечер: вход по системе", status: .pending),
                OnboardingStep(title: "После: разбор сделки", status: .pending)
            ]
        ),
        OnboardingPage(
            icon: "checklist",
            title: "Сделка — за минуту",
            subtitle: "Риск, вход, стоп и тейк в одной карточке, без таблиц",
            steps: [
                OnboardingStep(title: "Новая сделка: риск и уровни", status: .symbol("plus.circle")),
                OnboardingStep(title: "Открытые: цена и расстояние до TP", status: .symbol("chart.line.uptrend.xyaxis")),
                OnboardingStep(title: "Закрытые: R и разбор входа", status: .symbol("checkmark.circle"))
            ]
        ),
        OnboardingPage(
            icon: "chart.bar.xaxis",
            title: "Цифры покажут, что работает",
            subtitle: "Статистика, разбор месяца и Second Brain собирают выводы сами",
            steps: [
                OnboardingStep(title: "Статистика: winrate, PF, просадка", status: .symbol("chart.bar.xaxis")),
                OnboardingStep(title: "Second Brain: наблюдения и правила", status: .symbol("brain.head.profile")),
                OnboardingStep(title: "Поиск: одна строка по всей базе", status: .symbol("magnifyingglass"))
            ]
        )
    ]
}

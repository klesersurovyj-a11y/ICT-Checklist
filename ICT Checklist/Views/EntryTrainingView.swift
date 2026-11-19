//
//  EntryTrainingView.swift
//  ICT Checklist
//
//  «Тренировка входа»: цикл без денег — решения по шагам, оценка и что бы дало по R.
//

import SwiftUI
import SwiftData

struct EntryTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \TrainingRun.date, order: .reverse) private var runs: [TrainingRun]

    @State private var step = 0
    @State private var answers: [Int?] = Array(repeating: nil, count: 5)
    @State private var finished = false

    private var steps: [TrainingStep] { TrainingStep.all }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)

                    if finished {
                        resultCard
                            .reveal(.zoom, 2)
                        restartButton
                            .reveal(.rise, 3)
                    } else {
                        progressCard
                            .reveal(.zoom, 1)
                        contextCard
                            .reveal(.rise, 2)
                        primaryButton
                            .reveal(.rise, 3)
                        skipButton
                            .reveal(.rise, 3)
                    }

                    if !runs.isEmpty {
                        pastRunsCard
                            .reveal(.rise, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Тренировка")
                ScreenTitle(text: "Тренировка входа")
                Text("Пройди цикл без денег и посмотри, что бы вышло")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

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

    // MARK: - Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressRail

            Text("Шаг \(step + 1) из \(steps.count) · \(steps[step].title)")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)

            Text(steps[step].question)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(steps[step].options.enumerated()), id: \.offset) { index, option in
                    optionRow(option, index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var progressRail: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                ZStack {
                    if index < step {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                    } else if index == step {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                            .frame(width: 26, height: 26)
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 26, height: 26)
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(index < step ? 0.5 : 0.10))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func optionRow(_ option: TrainingOption, index: Int) -> some View {
        let isSelected = answers[step] == index

        return Button {
            answers[step] = index
            Haptics.select()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer(minLength: 6)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.22),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.75) : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.4 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var contextCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 46, height: 46)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("EURUSD · LONG · Лондон · FVG")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Цена 1.08420 · стоп 1.08120")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 4)
        }
        .padding(12)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Controls

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            Text(step == steps.count - 1 ? "Завершить" : "Дальше")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(answers[step] == nil)
        .opacity(answers[step] == nil ? 0.45 : 1)
        .padding(.top, 4)
    }

    private var skipButton: some View {
        Button {
            skipStep()
        } label: {
            Text("Пропустить шаг")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var restartButton: some View {
        Button {
            reset()
        } label: {
            Text("Ещё раз")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 4)
    }

    // MARK: - Result

    private var correctCount: Int {
        steps.indices.filter { isCorrect(step: $0) }.count
    }

    private var score: Int {
        Int((Double(correctCount) / Double(steps.count) * 100).rounded())
    }

    private var wouldBeR: Double {
        let directionOK = isCorrect(step: 0)
        let exitOK = isCorrect(step: 3)
        if !directionOK { return -1 }
        if exitOK { return 2 }
        return 0.5
    }

    private var resultExplanation: String {
        if !isCorrect(step: 0) {
            return "Вход против потока закрылся бы по стопу: −1R."
        }
        if isCorrect(step: 3) {
            return "Системный вход и тейк по плану дали бы +2R."
        }
        return "Направление верное, но цель взята раньше плана — прибыль была бы меньше."
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результат")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("из 100 · верно \(correctCount) из \(steps.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text("Что бы дало")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.r(wouldBeR))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rColor(wouldBeR))
            }

            Text(resultExplanation)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.hairline)

            VStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    breakdownRow(index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func breakdownRow(_ index: Int) -> some View {
        let ok = isCorrect(step: index)
        let chosen = answers[index].flatMap { value in
            value < steps[index].options.count ? steps[index].options[value].title : nil
        }
        let correctTitle = steps[index].options.first(where: { $0.isCorrect })?.title ?? "—"

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ok ? Theme.green : Theme.red)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(steps[index].title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text(chosen ?? "пропущено")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ok ? Theme.textSecondary : Theme.red.opacity(0.9))

                if !ok {
                    Text("По алгоритму: \(correctTitle)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Past runs

    private var pastRunsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Прошлые тренировки")

            VStack(spacing: 0) {
                ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(run.symbol)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("\(Fmt.shortDay(run.date)), \(Fmt.time(run.date))")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer(minLength: 6)

                        Text("\(run.score)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.10)))

                        Text(Fmt.r(run.wouldBeR))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rColor(run.wouldBeR))
                            .frame(width: 54, alignment: .trailing)

                        Button {
                            context.delete(run)
                            try? context.save()
                            Haptics.warning()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 26, height: 26)
                                .glassCircle()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)

                    if index < runs.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    // MARK: - Actions

    private func advance() {
        guard answers[step] != nil else { return }
        Haptics.tap()

        if step < steps.count - 1 {
            step += 1
        } else {
            finish()
        }
    }

    private func skipStep() {
        answers[step] = nil
        Haptics.tap()

        if step < steps.count - 1 {
            step += 1
        } else {
            finish()
        }
    }

    private func finish() {
        let summary = steps.indices
            .map { index in
                "\(steps[index].title): \(isCorrect(step: index) ? "верно" : "неверно")"
            }
            .joined(separator: " · ")

        let run = TrainingRun(
            date: .now,
            symbol: TrainingSymbol.value,
            score: score,
            correctSteps: correctCount,
            totalSteps: steps.count,
            wouldBeR: wouldBeR,
            summary: summary
        )
        context.insert(run)
        try? context.save()

        finished = true
        Haptics.success()
    }

    private func reset() {
        step = 0
        answers = Array(repeating: nil, count: 5)
        finished = false
        Haptics.tap()
    }

    private func isCorrect(step index: Int) -> Bool {
        guard let answer = answers[index],
              answer < steps[index].options.count else { return false }
        return steps[index].options[answer].isCorrect
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

// MARK: - Data

private struct TrainingOption {
    let title: String
    let subtitle: String?
    let isCorrect: Bool
}

private struct TrainingStep {
    let title: String
    let question: String
    let options: [TrainingOption]
}

private enum TrainingSymbol {
    static let value = "EURUSD"
}

private extension TrainingStep {
    static let all: [TrainingStep] = [
        TrainingStep(
            title: "Направление",
            question: "Куда идёт цена?",
            options: [
                TrainingOption(title: "LONG · от FVG", subtitle: "Продолжение потока", isCorrect: true),
                TrainingOption(title: "SHORT · против потока", subtitle: "Ставка на разворот", isCorrect: false)
            ]
        ),
        TrainingStep(
            title: "Риск",
            question: "Какой риск на сделку?",
            options: [
                TrainingOption(title: "12 USD", subtitle: "ступень 1", isCorrect: true),
                TrainingOption(title: "25 USD", subtitle: "ступень 2", isCorrect: false),
                TrainingOption(title: "50 USD", subtitle: "ступень 3", isCorrect: false)
            ]
        ),
        TrainingStep(
            title: "Вход",
            question: "Где входить?",
            options: [
                TrainingOption(title: "После ретеста FVG", subtitle: "Ждём подтверждения", isCorrect: true),
                TrainingOption(title: "Сразу по рынку", subtitle: "Без ретеста", isCorrect: false),
                TrainingOption(title: "Против движения", subtitle: "Ставка на разворот", isCorrect: false)
            ]
        ),
        TrainingStep(
            title: "Цель",
            question: "Когда закрывать?",
            options: [
                TrainingOption(title: "Тейк 1.09020 · RR 2.0", subtitle: "По плану", isCorrect: true),
                TrainingOption(title: "На половине пути", subtitle: "RR 1.0", isCorrect: false),
                TrainingOption(title: "Без тейка", subtitle: "Держать до конца дня", isCorrect: false)
            ]
        ),
        TrainingStep(
            title: "Разбор",
            question: "Что после закрытия?",
            options: [
                TrainingOption(title: "Записать причину и результат", subtitle: "Разбор сделки", isCorrect: true),
                TrainingOption(title: "Сразу новая сделка", subtitle: "Без паузы", isCorrect: false),
                TrainingOption(title: "Закрыть терминал", subtitle: "До завтра", isCorrect: false)
            ]
        )
    ]
}

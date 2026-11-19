//
//  InvestmentMemoCard.swift
//  ICT Checklist
//
//  Меморандум сделки: тезис, что в цене, сценарии, инвалидация,
//  красная команда и вердикт комитета.
//

import SwiftUI

struct InvestmentMemoCard: View {
    @Binding var thesis: String
    @Binding var pricedIn: String
    @Binding var scenarios: String
    @Binding var invalidation: String
    @Binding var answers: String
    @Binding var rejectReason: String
    @Binding var verdictRaw: String

    let objections: [RedTeamObjection]
    let historyObjections: [RedTeamHistoryObjection]
    @Binding var replies: [String: String]

    private var verdict: MemoVerdict {
        MemoVerdict(rawValue: verdictRaw) ?? .none
    }

    private var canApprove: Bool {
        InvestmentCommittee.canApprove(
            thesis: thesis,
            invalidation: invalidation,
            objections: objections,
            answers: answers
        ) && historyAnswered
    }

    private var historyAnswered: Bool {
        RedTeamHistory.isAnswered(historyObjections, replies: replies)
    }

    private var canShowActions: Bool {
        let structuralAnswered = objections.isEmpty
            || !answers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return structuralAnswered && historyAnswered
    }

    private var canReject: Bool {
        !rejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Меморандум")
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Image(systemName: verdict.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(verdict.title.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(verdict.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(verdict.tint.opacity(0.14)))
            }

            Text("Комитет из одного человека: сначала тезис и инвалидация, потом размер. Без ответов на возражения вход не утверждается.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            GlassNoteField(
                placeholder: "Тезис: почему цена должна пойти к цели…",
                text: $thesis,
                limit: 400,
                lines: 2...4,
                minHeight: 56
            )

            GlassNoteField(
                placeholder: "Что уже в цене: ожидания, позиционирование, новости",
                text: $pricedIn,
                limit: 400,
                lines: 2...4,
                minHeight: 56
            )

            GlassNoteField(
                placeholder: "Сценарий A — к цели, сценарий B — против",
                text: $scenarios,
                limit: 400,
                lines: 2...5,
                minHeight: 64
            )

            GlassNoteField(
                placeholder: "Инвалидация: что отменит идею",
                text: $invalidation,
                limit: 300,
                lines: 1...3,
                minHeight: 48
            )

            redTeam

            historyTeam

            GlassNoteField(
                placeholder: "Причина отказа: что именно не так с идеей",
                text: $rejectReason,
                limit: 300,
                lines: 1...3,
                minHeight: 46
            )

            if canShowActions {
                HStack(spacing: 8) {
                    Button {
                        verdictRaw = MemoVerdict.approved.rawValue
                        Haptics.success()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Утвердить")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(canApprove ? Theme.accent : Theme.accent.opacity(0.3)))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canApprove)

                    Button {
                        verdictRaw = MemoVerdict.rejected.rawValue
                        Haptics.warning()
                    } label: {
                        Text("Отклонить")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(canReject ? Theme.red : Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Theme.red.opacity(canReject ? 0.12 : 0.05)))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canReject)
                }
                .padding(.top, 2)

                if !canReject {
                    Text("Отказ фиксируется с причиной: заполните поле выше.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(
                    historyAnswered
                        ? "Ответьте на возражения, чтобы утвердить сделку."
                        : "Ответьте на каждое возражение по истории — это условие утверждения."
                )
                .font(.system(size: 11))
                .foregroundStyle(Theme.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    @ViewBuilder
    private var redTeam: some View {
        if objections.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 11, weight: .semibold))
                Text("Красная команда возражений не нашла")
                    .font(.system(size: 11.5, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.green)
            .padding(.top, 2)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("КРАСНАЯ КОМАНДА")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.orange)

                ForEach(objections) { objection in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.orange)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(objection.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(objection.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }

                GlassNoteField(
                    placeholder: "Ваш ответ на возражения",
                    text: $answers,
                    limit: 400,
                    lines: 2...4,
                    minHeight: 56
                )
                .padding(.top, 2)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.orange.opacity(0.08))
            )
        }
    }

    @ViewBuilder
    private var historyTeam: some View {
        if !historyObjections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("КРАСНАЯ КОМАНДА ПО ИСТОРИИ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.red.opacity(0.9))

                    Spacer(minLength: 0)

                    Text("\(historyObjections.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.red.opacity(0.14)))
                }

                ForEach(historyObjections) { objection in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(objection.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(objection.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(objection.evidence) { item in
                            Text("\(Fmt.dayMonth(item.day)) · \(item.symbol) · \(Fmt.r(item.r)) · \(item.reason)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        GlassNoteField(
                            placeholder: "Ответ: почему на этот раз иначе",
                            text: replyBinding(objection),
                            limit: 400,
                            lines: 2...3,
                            minHeight: 48
                        )
                        .padding(.top, 2)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.red.opacity(0.07))
            )
        }
    }

    private func replyBinding(_ objection: RedTeamHistoryObjection) -> Binding<String> {
        Binding(
            get: { replies[objection.id] ?? "" },
            set: { replies[objection.id] = $0 }
        )
    }
}

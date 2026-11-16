//
//  LadderEngine.swift
//  ICT Checklist
//

import Foundation
import SwiftData

struct LadderSnapshot {
    struct Event: Identifiable {
        let id = UUID()
        let date: Date
        let fromStep: Int
        let toStep: Int
        let reason: String
        let isUp: Bool
    }

    var stepIndex: Int
    var accumulatedR: Double
    var events: [Event]

    static let targetR: Double = 2.0
    static let lastStepIndex: Int = 2
}

enum LadderEngine {
    /// Recomputes the continuous Risk Ladder from every closed trade in closing order.
    static func evaluate(trades: [Trade]) -> LadderSnapshot {
        let closed = trades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }

        var step = 0
        var accumulated = 0.0
        var events: [LadderSnapshot.Event] = []

        for trade in closed {
            let r = trade.actualR
            let date = closeDate(trade)

            if r > 0.05 {
                accumulated += r
                guard accumulated >= LadderSnapshot.targetR - 0.0001 else { continue }

                if step < LadderSnapshot.lastStepIndex {
                    let from = step
                    step += 1
                    accumulated = 0
                    events.append(
                        LadderSnapshot.Event(
                            date: date,
                            fromStep: from,
                            toStep: step,
                            reason: "TP \(Fmt.r(r)) — набрано +2R",
                            isUp: true
                        )
                    )
                } else {
                    accumulated = 0
                    events.append(
                        LadderSnapshot.Event(
                            date: date,
                            fromStep: step,
                            toStep: step,
                            reason: "TP на потолке — остаёмся",
                            isUp: true
                        )
                    )
                }
            } else if r < -0.05 {
                accumulated = 0
                if step > 0 {
                    let from = step
                    step = 0
                    events.append(
                        LadderSnapshot.Event(
                            date: date,
                            fromStep: from,
                            toStep: 0,
                            reason: "SL \(Fmt.r(r)) — сброс на старт",
                            isUp: false
                        )
                    )
                }
            }
        }

        return LadderSnapshot(stepIndex: step, accumulatedR: accumulated, events: events)
    }

    /// Recomputes and persists the ladder state, so it survives relaunch and feeds the checklist.
    @discardableResult
    static func sync(context: ModelContext) -> LadderSnapshot {
        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let snapshot = evaluate(trades: trades)

        let states = (try? context.fetch(FetchDescriptor<RiskLadderState>())) ?? []
        let state: RiskLadderState
        if let existing = states.first {
            state = existing
        } else {
            let created = RiskLadderState()
            context.insert(created)
            state = created
        }

        if state.stepIndex != snapshot.stepIndex
            || abs(state.accumulatedR - snapshot.accumulatedR) > 0.0001 {
            state.stepIndex = snapshot.stepIndex
            state.accumulatedR = snapshot.accumulatedR
            state.updatedAt = .now
            try? context.save()
        }

        WidgetSnapshot.refresh(context: context)

        return snapshot
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

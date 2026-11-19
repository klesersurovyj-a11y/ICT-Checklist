//
//  AdviceJournal.swift
//  ICT Checklist
//
//  Прогресс проверки совета: сколько сделок прошло, сколько R было
//  до гипотезы и сколько стало после.
//

import Foundation

struct AdviceProgress {
    var tradesAfter = 0
    var closedCount = 0
    var rBefore = 0.0
    var rAfter = 0.0
    var isDue = false
    var tradesLeft = 0
}

enum AdviceJournal {
    static func progress(
        for hypothesis: AdviceHypothesis,
        trades: [Trade]
    ) -> AdviceProgress {
        let closed = trades
            .filter { $0.result != .open }
            .sorted { closeDate($0) < closeDate($1) }

        let before = closed.filter { closeDate($0) < hypothesis.createdAt }
        let after = closed.filter { closeDate($0) >= hypothesis.createdAt }

        let needed = max(hypothesis.checkAfterTrades, 1)

        return AdviceProgress(
            tradesAfter: after.count,
            closedCount: closed.count,
            rBefore: before.reduce(0) { $0 + $1.actualR },
            rAfter: after.reduce(0) { $0 + $1.actualR },
            isDue: after.count >= needed,
            tradesLeft: max(0, needed - after.count)
        )
    }

    static func checkAfterTrades(_ hypothesis: AdviceHypothesis) -> Int {
        max(hypothesis.checkAfterTrades, 1)
    }

    /// Срок проверки в сделках от момента создания.
    static func deadline(_ hypothesis: AdviceHypothesis) -> Int {
        checkAfterTrades(hypothesis)
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.entryDate
    }
}

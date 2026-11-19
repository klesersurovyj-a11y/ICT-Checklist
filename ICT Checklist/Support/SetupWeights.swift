//
//  SetupWeights.swift
//  ICT Checklist
//
//  Целевые веса сетапов из мандата против фактических и предложение ребаланса.
//

import Foundation

struct SetupWeightInfo: Identifiable {
    let name: String
    let target: Double
    let actual: Double
    let count: Int
    let r: Double

    var id: String { name }

    var excess: Double { actual - target }
    var isOver: Bool { excess > 1 }
    var isUnder: Bool { excess < -1 }
}

struct SetupWeightProposal: Identifiable {
    let name: String
    let target: Double
    let proposed: Double

    var id: String { name }
}

struct SetupWeightsReport {
    var hasMandate = false
    var rows: [SetupWeightInfo] = []
    var proposal: [SetupWeightProposal] = []
    var note = ""
}

enum SetupWeights {
    static func report(
        trades: [Trade],
        mandate: FundMandate?,
        setups: [PlaybookSetup],
        now: Date = .now,
        days: Int = 90,
        calendar: Calendar = .current
    ) -> SetupWeightsReport {
        var report = SetupWeightsReport()
        guard let mandate else { return report }
        report.hasMandate = true

        let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        let recent = trades.filter { trade in
            guard trade.result != .open else { return false }
            let date = trade.closedAt ?? trade.tradingDay
            return date >= start
        }

        var names: [String] = []
        for setup in setups where !setup.isArchived {
            let title = setup.title
            if !title.isEmpty, !names.contains(title) {
                names.append(title)
            }
        }
        for trade in trades where !trade.setupName.isEmpty {
            if !names.contains(trade.setupName) {
                names.append(trade.setupName)
            }
        }
        guard !names.isEmpty else { return report }

        let stored = mandate.setupWeights
        let equal = 100.0 / Double(names.count)
        var targets: [String: Double] = [:]
        for name in names {
            targets[name] = stored[name] ?? equal
        }

        let totalCount = recent.count
        report.rows = names.map { name in
            let list = recent.filter { $0.setupName == name }
            return SetupWeightInfo(
                name: name,
                target: targets[name] ?? equal,
                actual: totalCount > 0 ? Double(list.count) / Double(totalCount) * 100 : 0,
                count: list.count,
                r: list.reduce(0) { $0 + $1.actualR }
            )
        }

        var proposal = targets
        if let worst = report.rows
            .filter({ $0.count >= 3 && $0.r < -0.05 })
            .min(by: { $0.r < $1.r }),
           let best = report.rows
            .filter({ $0.count >= 3 })
            .max(by: { $0.r < $1.r }),
           best.name != worst.name {
            let available = (proposal[worst.name] ?? 0) - 5
            let shift = min(10, max(available, 0))
            if shift > 0 {
                proposal[worst.name, default: 0] -= shift
                proposal[best.name, default: 0] += shift
            }
        }

        // Округление до 5% и приведение к 100%.
        var rounded = proposal.mapValues { max(0, (($0 / 5).rounded()) * 5) }
        let sum = rounded.values.reduce(0, +)
        if let anchor = names.max(by: { (rounded[$0] ?? 0) < (rounded[$1] ?? 0) }) {
            rounded[anchor, default: 0] += 100 - sum
            if (rounded[anchor] ?? 0) <= 0 {
                rounded[anchor] = 5
            }
        }

        report.proposal = names.map {
            SetupWeightProposal(
                name: $0,
                target: targets[$0] ?? equal,
                proposed: rounded[$0] ?? 0
            )
        }

        var changed = false
        for row in report.proposal where abs(row.proposed - row.target) > 0.1 {
            changed = true
        }
        report.note = changed
            ? "округлено до 5%, гипотеза: срезать перевес худшего сетапа"
            : "веса в норме, менять нечего"

        return report
    }
}

//
//  SystemVersions.swift
//  ICT Checklist
//
//  Активная версия, предыдущая версия и результат до и после.
//

import Foundation

struct VersionResult {
    var beforeR = 0.0
    var afterR = 0.0
    var tradesAfter = 0
}

enum SystemVersions {
    static func sorted(_ versions: [SystemVersion]) -> [SystemVersion] {
        versions.sorted { $0.version > $1.version }
    }

    static func active(_ versions: [SystemVersion]) -> SystemVersion? {
        versions.first { $0.isActive } ?? sorted(versions).first
    }

    static func previous(_ versions: [SystemVersion], of version: SystemVersion?) -> SystemVersion? {
        guard let version else { return nil }
        return sorted(versions).first { $0.version < version.version }
    }

    static func nextVersion(_ versions: [SystemVersion]) -> Int {
        (versions.map(\.version).max() ?? 0) + 1
    }

    /// Результат до и после версии: закрытые сделки вокруг её даты.
    static func result(for version: SystemVersion, trades: [Trade]) -> VersionResult {
        let closed = trades.filter { $0.result != .open }
        let before = closed.filter { closeDate($0) < version.createdAt }
        let after = closed.filter { closeDate($0) >= version.createdAt }

        return VersionResult(
            beforeR: before.reduce(0) { $0 + $1.actualR },
            afterR: after.reduce(0) { $0 + $1.actualR },
            tradesAfter: after.count
        )
    }

    private static func closeDate(_ trade: Trade) -> Date {
        trade.closedAt ?? trade.tradeCloseFallback
    }
}

private extension Trade {
    var tradeCloseFallback: Date { entryDate }
}

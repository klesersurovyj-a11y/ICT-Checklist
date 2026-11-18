//
//  TradingAccount.swift
//  ICT Checklist
//

import Foundation
import SwiftData

enum AccountType: String, CaseIterable, Identifiable {
    case personal = "Личный"
    case prop = "Prop"
    case demo = "Demo"
    case other = "Другой"

    var id: String { rawValue }

    var tint: String {
        switch self {
        case .personal: return "accent"
        case .prop: return "green"
        case .demo: return "orange"
        case .other: return "secondary"
        }
    }
}

enum AccountOperationKind: String, CaseIterable, Identifiable {
    case payout = "Получил выплату"
    case withdrawal = "Вывод средств"
    case deposit = "Пополнение"
    case fee = "Комиссия"
    case transfer = "Перевод"

    var id: String { rawValue }

    var isIncoming: Bool {
        self == .payout || self == .deposit
    }

    var sign: Double {
        isIncoming ? 1 : -1
    }

    var shortTitle: String {
        switch self {
        case .payout: return "Выплата"
        case .withdrawal: return "Вывод"
        case .deposit: return "Пополнение"
        case .fee: return "Комиссия"
        case .transfer: return "Перевод"
        }
    }
}

@Model
final class TradingAccount {
    var name: String = ""
    var typeRaw: String = AccountType.personal.rawValue
    var currency: String = "USD"
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var startingBalance: Double = 0
    /// Счёт загружен демо-базой и удаляется одной кнопкой в настройках.
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \AccountOperation.account)
    var operations: [AccountOperation] = []

    @Relationship(deleteRule: .nullify, inverse: \Trade.account)
    var trades: [Trade] = []

    init(
        name: String = "",
        type: AccountType = .personal,
        currency: String = "USD",
        startingBalance: Double = 0
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.currency = currency
        self.createdAt = .now
        self.isArchived = false
        self.startingBalance = startingBalance
        self.isDemo = false
        self.operations = []
        self.trades = []
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .personal }
        set { typeRaw = newValue.rawValue }
    }

    var sortedOperations: [AccountOperation] {
        operations.sorted { $0.date > $1.date }
    }

    var payoutTotal: Double {
        operations
            .filter { $0.kind == .payout }
            .reduce(0) { $0 + $1.amount }
    }

    var withdrawalTotal: Double {
        operations
            .filter { $0.kind == .withdrawal }
            .reduce(0) { $0 + $1.amount }
    }

    var depositTotal: Double {
        operations
            .filter { $0.kind == .deposit }
            .reduce(0) { $0 + $1.amount }
    }

    var feeTotal: Double {
        operations
            .filter { $0.kind == .fee }
            .reduce(0) { $0 + $1.amount }
    }

    var transferInTotal: Double {
        operations
            .filter { $0.kind == .transfer && $0.isTransferIncoming }
            .reduce(0) { $0 + $1.amount }
    }

    var transferOutTotal: Double {
        operations
            .filter { $0.kind == .transfer && !$0.isTransferIncoming }
            .reduce(0) { $0 + $1.amount }
    }

    var netTotal: Double {
        payoutTotal + depositTotal - withdrawalTotal - feeTotal
    }

    /// Текущий баланс счёта: начальный, плюс пополнения и входящие переводы,
    /// минус выводы, комиссии, выплаты и исходящие переводы.
    var balance: Double {
        startingBalance
            + depositTotal
            - withdrawalTotal
            - feeTotal
            - payoutTotal
            + transferInTotal
            - transferOutTotal
    }

    func operations(inMonthOf date: Date, calendar: Calendar = .current) -> [AccountOperation] {
        operations.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    var tradeCount: Int {
        trades.count
    }

    var totalR: Double {
        trades.reduce(0) { $0 + $1.actualR }
    }

    /// Денежный результат закрытых сделок счёта.
    var tradeProfit: Double {
        trades
            .filter { $0.result != .open }
            .reduce(0) { $0 + $1.moneyResult }
    }

    /// Реальный капитал счёта: баланс по операциям плюс результат сделок.
    var equity: Double {
        balance + tradeProfit
    }
}

@Model
final class AccountOperation {
    var kindRaw: String = AccountOperationKind.payout.rawValue
    var amount: Double = 0
    var date: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()
    /// Общий идентификатор двух половин перевода.
    var transferID: String = ""
    /// true — перевод пришёл на этот счёт, false — ушёл с него.
    var isTransferIncoming: Bool = false
    var account: TradingAccount?

    init(
        kind: AccountOperationKind = .payout,
        amount: Double = 0,
        date: Date = .now,
        note: String = ""
    ) {
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.date = date
        self.note = note
        self.createdAt = .now
        self.transferID = ""
        self.isTransferIncoming = false
        self.account = nil
    }

    var kind: AccountOperationKind {
        get { AccountOperationKind(rawValue: kindRaw) ?? .payout }
        set { kindRaw = newValue.rawValue }
    }

    var signedAmount: Double {
        switch kind {
        case .payout, .deposit:
            return amount
        case .withdrawal, .fee:
            return -amount
        case .transfer:
            return isTransferIncoming ? amount : -amount
        }
    }
}

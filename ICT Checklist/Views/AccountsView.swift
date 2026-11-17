//
//  AccountsView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import Charts

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var showNewAccount = false
    @State private var operationAccount: TradingAccount?
    @State private var showTransfer = false
    @State private var transferSource: TradingAccount?
    @State private var accountToDelete: TradingAccount?
    @State private var operationToDelete: AccountOperation?
    @State private var balanceAccountKey: String?

    private var allPayouts: Double {
        accounts.reduce(0) { $0 + $1.payoutTotal }
    }

    private var allWithdrawals: Double {
        accounts.reduce(0) { $0 + $1.withdrawalTotal }
    }

    private var allBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var monthOperations: [AccountOperation] {
        accounts.flatMap { $0.operations(inMonthOf: .now) }
    }

    private var monthNet: Double {
        monthOperations.reduce(0) { $0 + $1.signedAmount }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                        .reveal(.slideLeft)
                    summaryTiles
                        .reveal(.zoom, 1)
                    monthLine
                        .reveal(.blur, 2)

                    if !accounts.isEmpty {
                        balancesCard
                            .reveal(.rise, 2)
                    }

                    if accounts.isEmpty {
                        emptyCard
                            .reveal(.rise, 3)
                    } else {
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                            accountCard(account)
                                .reveal(.rise, index + 4)
                        }
                    }

                    addAccountButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showNewAccount) {
            AccountEditorSheet { name, type, currency, startingBalance in
                let account = TradingAccount(
                    name: name,
                    type: type,
                    currency: currency,
                    startingBalance: startingBalance
                )
                context.insert(account)
                try? context.save()
                Haptics.success()
            }
        }
        .sheet(item: $operationAccount) { account in
            OperationSheet(account: account) { kind, amount, date, note in
                let operation = AccountOperation(kind: kind, amount: amount, date: date, note: note)
                context.insert(operation)
                operation.account = account
                try? context.save()
                Haptics.success()
            }
        }
        .sheet(isPresented: $showTransfer) {
            TransferSheet(accounts: accounts, initialSource: transferSource) { source, destination, amount, date, note in
                let group = UUID().uuidString

                let outgoing = AccountOperation(kind: .transfer, amount: amount, date: date, note: note)
                outgoing.transferID = group
                outgoing.isTransferIncoming = false
                context.insert(outgoing)
                outgoing.account = source

                let incoming = AccountOperation(kind: .transfer, amount: amount, date: date, note: note)
                incoming.transferID = group
                incoming.isTransferIncoming = true
                context.insert(incoming)
                incoming.account = destination

                try? context.save()
                Haptics.success()
            }
        }
        .alert("Удалить счёт?", isPresented: deleteAccountBinding) {
            Button("Удалить", role: .destructive) {
                if let account = accountToDelete {
                    context.delete(account)
                    try? context.save()
                    Haptics.warning()
                }
                accountToDelete = nil
            }
            Button("Отмена", role: .cancel) { accountToDelete = nil }
        } message: {
            Text("Счёт и все его операции будут удалены.")
        }
        .alert("Удалить операцию?", isPresented: deleteOperationBinding) {
            Button("Удалить", role: .destructive) {
                if let operation = operationToDelete {
                    delete(operation)
                }
                operationToDelete = nil
            }
            Button("Отмена", role: .cancel) { operationToDelete = nil }
        } message: {
            Text("Операция исчезнет из истории счёта.")
        }
    }

    private var deleteAccountBinding: Binding<Bool> {
        Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )
    }

    private var deleteOperationBinding: Binding<Bool> {
        Binding(
            get: { operationToDelete != nil },
            set: { if !$0 { operationToDelete = nil } }
        )
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
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Аккаунты")
                ScreenTitle(text: "Счета и выплаты")
            }

            Spacer(minLength: 8)
        }
    }

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            tile("Баланс", money(allBalance, "USD"), tint: Theme.textPrimary)
            tile("Выплаты", money(allPayouts, "USD"), tint: Theme.green)
            tile("Выводы", money(allWithdrawals, "USD"), tint: Theme.orange)
            tile("Счетов", "\(accounts.count)", tint: Theme.textSecondary)
        }
    }

    private func tile(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(cornerRadius: 16)
    }

    private var monthLine: some View {
        HStack(spacing: 8) {
            Text("В этом месяце")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(monthOperations.count) \(operationsWord(monthOperations.count)) · ")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                + Text(money(monthNet, "USD"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(monthNet >= 0 ? Theme.green : Theme.orange)
        }
    }

    private func operationsWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "операций" }
        if mod10 == 1 { return "операция" }
        if mod10 >= 2 && mod10 <= 4 { return "операции" }
        return "операций"
    }

    // MARK: - Balances

    private static let balancePalette: [Color] = [
        Color.white,
        Color.white.opacity(0.62),
        Color.white.opacity(0.38),
        Color.white.opacity(0.82),
        Color.white.opacity(0.24)
    ]

    private static let balanceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private func balanceKey(for account: TradingAccount) -> String {
        "\(account.persistentModelID)"
    }

    private func balanceColor(for account: TradingAccount) -> Color {
        let index = accounts.firstIndex { $0.persistentModelID == account.persistentModelID } ?? 0
        return Self.balancePalette[index % Self.balancePalette.count]
    }

    private var balanceSeries: [BalanceSeries] {
        let selected = balanceAccountKey
        return accounts.compactMap { account in
            if let selected, selected != balanceKey(for: account) { return nil }
            return makeBalanceSeries(for: account)
        }
    }

    private func makeBalanceSeries(for account: TradingAccount) -> BalanceSeries? {
        let operations = account.operations.sorted { $0.date < $1.date }
        guard !operations.isEmpty else { return nil }

        let calendar = Calendar.current
        var startDate = calendar.startOfDay(for: account.createdAt)
        if let first = operations.first?.date, first < startDate {
            startDate = calendar.startOfDay(for: first)
        }

        var points: [BalancePoint] = [
            BalancePoint(id: "start", date: startDate, value: account.startingBalance)
        ]
        var running = account.startingBalance

        for (index, operation) in operations.enumerated() {
            running += operation.signedAmount
            points.append(BalancePoint(id: "op-\(index)", date: operation.date, value: running))
        }

        return BalanceSeries(
            id: balanceKey(for: account),
            name: account.name.isEmpty ? "Счёт без названия" : account.name,
            color: balanceColor(for: account),
            points: points
        )
    }

    private var balanceMenuTitle: String {
        guard let selected = balanceAccountKey else { return "Все счета" }
        let account = accounts.first { balanceKey(for: $0) == selected }
        guard let account else { return "Все счета" }
        return account.name.isEmpty ? "Счёт без названия" : account.name
    }

    private var balancesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(text: "Балансы")
                Spacer(minLength: 8)
                balanceMenu
            }

            if balanceSeries.isEmpty {
                Text("Пока нет операций — баланс не менялся")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                balanceChart
                balanceLegend
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            HStack(spacing: 8) {
                Text("Итого на счетах")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Text(money(allBalance, "USD"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(allBalance < 0 ? Theme.red : Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var balanceMenu: some View {
        Menu {
            Button {
                withAnimation(Theme.snappy) {
                    balanceAccountKey = nil
                }
                Haptics.select()
            } label: {
                if balanceAccountKey == nil {
                    Label("Все счета", systemImage: "checkmark")
                } else {
                    Text("Все счета")
                }
            }

            ForEach(accounts) { account in
                Button {
                    withAnimation(Theme.snappy) {
                        balanceAccountKey = balanceKey(for: account)
                    }
                    Haptics.select()
                } label: {
                    if balanceAccountKey == balanceKey(for: account) {
                        Label(account.name, systemImage: "checkmark")
                    } else {
                        Text(account.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(balanceMenuTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    private var balanceChart: some View {
        Chart {
            ForEach(balanceSeries) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Баланс", point.value),
                        series: .value("Счёт", series.name)
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }

            RuleMark(y: .value("Ноль", 0))
                .foregroundStyle(Color.white.opacity(0.10))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(compactMoney(number))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.balanceDateFormatter.string(from: date))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 170)
    }

    private var balanceLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(balanceSeries) { series in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(series.color)
                            .frame(width: 7, height: 7)
                        Text(series.name)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func compactMoney(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    // MARK: - Accounts

    private func accountCard(_ account: TradingAccount) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(account.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(account.type.rawValue)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(typeTint(account.type))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(typeTint(account.type).opacity(0.14)))
                    .overlay(Capsule().strokeBorder(typeTint(account.type).opacity(0.32), lineWidth: 1))

                Text(account.currency)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)

                Spacer(minLength: 6)

                Button {
                    accountToDelete = account
                    Haptics.tap()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Баланс")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(money(account.balance, account.currency))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(account.balance < 0 ? Theme.red : Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                Text("начальный \(money(account.startingBalance, account.currency))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 8) {
                miniPill("Выплаты \(money(account.payoutTotal, account.currency))", tint: Theme.green)
                miniPill("Выводы \(money(account.withdrawalTotal, account.currency))", tint: Theme.orange)
                if !account.trades.isEmpty {
                    miniPill("Сделок \(account.trades.count)", tint: Theme.lavender)
                }
            }

            if account.operations.isEmpty {
                Text("Пока нет операций")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(account.sortedOperations) { operation in
                        operationRow(operation, currency: account.currency)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    operationAccount = account
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Добавить операцию")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.plain)

                Button {
                    transferSource = account
                    showTransfer = true
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("Перевод")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .disabled(accounts.count < 2)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func operationRow(_ operation: AccountOperation, currency: String) -> some View {
        let isTransfer = operation.kind == .transfer
        let isIncoming = isTransfer ? operation.isTransferIncoming : operation.kind.isIncoming
        let tint: Color = isTransfer ? Theme.textPrimary : (isIncoming ? Theme.green : Theme.orange)

        return HStack(spacing: 10) {
            Image(systemName: operationIcon(operation))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(operation.kind.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(operationLine(operation))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text((isIncoming ? "+" : "\u{2212}") + money(operation.amount, currency))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                operationToDelete = operation
                Haptics.tap()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private func operationIcon(_ operation: AccountOperation) -> String {
        if operation.kind == .transfer {
            return "arrow.left.arrow.right"
        }
        return operation.kind.isIncoming ? "arrow.down.left" : "arrow.up.right"
    }

    private func operationLine(_ operation: AccountOperation) -> String {
        let date = Fmt.shortDay(operation.date)
        let note = operation.note.trimmingCharacters(in: .whitespacesAndNewlines)

        if operation.kind == .transfer {
            var parts = [date]
            if let counterpart = transferCounterpart(operation) {
                parts.append(operation.isTransferIncoming ? "из \(counterpart.name)" : "→ \(counterpart.name)")
            }
            if !note.isEmpty { parts.append(note) }
            return parts.joined(separator: " · ")
        }

        return note.isEmpty ? date : "\(date) · \(note)"
    }

    private func transferCounterpart(_ operation: AccountOperation) -> TradingAccount? {
        guard operation.kind == .transfer, !operation.transferID.isEmpty else { return nil }
        for account in accounts where account.persistentModelID != operation.account?.persistentModelID {
            if account.operations.contains(where: { $0.transferID == operation.transferID }) {
                return account
            }
        }
        return nil
    }

    private func delete(_ operation: AccountOperation) {
        if operation.kind == .transfer, !operation.transferID.isEmpty {
            let sibling = accounts
                .flatMap { $0.operations }
                .first { $0 !== operation && $0.transferID == operation.transferID }
            if let sibling {
                context.delete(sibling)
            }
        }
        context.delete(operation)
        try? context.save()
        Haptics.warning()
    }

    private func miniPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func typeTint(_ type: AccountType) -> Color {
        switch type {
        case .personal: return Theme.accent
        case .prop: return Theme.green
        case .demo: return Theme.orange
        case .other: return Theme.textSecondary
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Счетов пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Добавьте личный счёт, prop-счёт или демо и записывайте выплаты и выводы средств.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private var addAccountButton: some View {
        Button {
            showNewAccount = true
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Добавить счёт")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
            .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 6)
    }

    private func money(_ value: Double, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
        let text = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.0f", abs(value))
        return "\(currency) \(text)"
    }
}

// MARK: - Balances

private struct BalancePoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

private struct BalanceSeries: Identifiable {
    let id: String
    let name: String
    let color: Color
    let points: [BalancePoint]
}

// MARK: - New account

private struct AccountEditorSheet: View {
    let onSave: (String, AccountType, String, Double) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .personal
    @State private var currency = "USD"
    @State private var startingBalanceText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Новый счёт")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    save()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextField("Название, например FTMO", text: $name)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AccountType.allCases) { item in
                        Chip(title: item.rawValue, isSelected: type == item) {
                            type = item
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack(spacing: 8) {
                Text("Валюта")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("USD", text: $currency)
                    .textInputAutocapitalization(.characters)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(width: 110)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text("Начальный баланс")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $startingBalanceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(width: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = startingBalanceText.replacingOccurrences(of: ",", with: ".")
        let balance = Double(normalized) ?? 0
        onSave(trimmed, type, code.isEmpty ? "USD" : code.uppercased(), balance)
        dismiss()
    }
}

// MARK: - Transfer

private struct TransferSheet: View {
    let accounts: [TradingAccount]
    let initialSource: TradingAccount?

    let onSave: (TradingAccount, TradingAccount, Double, Date, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var source: TradingAccount?
    @State private var destination: TradingAccount?
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var didLoad = false

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        guard let source, let destination, amount > 0 else { return false }
        return source.persistentModelID != destination.persistentModelID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Перевод")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    save()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .disabled(!canSave)
            }

            accountPicker(title: "Со счёта", selection: $source, excluding: nil)
            accountPicker(title: "На счёт", selection: $destination, excluding: source)

            HStack(spacing: 10) {
                Text("Сумма")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(width: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                Spacer(minLength: 0)
                Text(source?.currency ?? "USD")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            DatePicker("Дата", selection: $date, displayedComponents: .date)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .tint(Theme.accent)

            TextField("Заметка", text: $note)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

            Text("Перевод не считается выплатой или выводом: баланс одного счёта уменьшается, другого — увеличивается.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
        .onAppear(perform: loadDefaults)
    }

    private func accountPicker(
        title: String,
        selection: Binding<TradingAccount?>,
        excluding: TradingAccount?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)

            Menu {
                ForEach(accounts.filter { $0.persistentModelID != excluding?.persistentModelID }) { account in
                    Button("\(account.name) · \(account.currency)") {
                        selection.wrappedValue = account
                        Haptics.select()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.wrappedValue?.name ?? "Выберите счёт")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection.wrappedValue == nil ? Theme.textSecondary : .white)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
    }

    private func loadDefaults() {
        guard !didLoad else { return }
        didLoad = true

        let first = initialSource ?? accounts.first
        source = first
        destination = accounts.first { $0.persistentModelID != first?.persistentModelID }
    }

    private func save() {
        guard let source, let destination, canSave else { return }
        onSave(
            source,
            destination,
            amount,
            date,
            note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}


// MARK: - Operation

private struct OperationSheet: View {
    let account: TradingAccount
    let onSave: (AccountOperationKind, Double, Date, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: AccountOperationKind = .payout
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Новая операция")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    save()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .disabled(amount <= 0)
            }

            Text(account.name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AccountOperationKind.allCases.filter { $0 != .transfer }) { item in
                        Chip(
                            title: item.shortTitle,
                            isSelected: kind == item,
                            tint: item.isIncoming ? Theme.green : Theme.orange
                        ) {
                            kind = item
                            Haptics.select()
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack(spacing: 10) {
                Text("Сумма")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(width: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                Spacer(minLength: 0)
                Text(account.currency)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            DatePicker("Дата", selection: $date, displayedComponents: .date)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .tint(Theme.accent)

            TextField("Заметка", text: $note)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
    }

    private var amount: Double {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func save() {
        guard amount > 0 else { return }
        onSave(kind, amount, date, note.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}

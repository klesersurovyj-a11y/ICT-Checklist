//
//  CSVImportView.swift
//  ICT Checklist
//
//  «Импорт из CSV»: файл, разбор колонок, предпросмотр, счёт и итог.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \TradingAccount.createdAt) private var accounts: [TradingAccount]

    @State private var rows: [CSVImportRow] = []
    @State private var fileName: String?
    @State private var fileMeta = ""
    @State private var account: TradingAccount?
    @State private var showImporter = false
    @State private var errorText: String?
    @State private var added = 0
    @State private var skipped = 0
    @State private var didImport = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                        .reveal(.drop)
                    fileCard
                        .reveal(.zoom, 1)

                    if let first = rows.first {
                        columnsCard(first)
                            .reveal(.rise, 2)
                        previewCard
                            .reveal(.rise, 3)
                    }

                    accountCard
                        .reveal(.rise, 4)

                    if didImport {
                        resultCard
                            .reveal(.rise, 5)
                    }

                    importButton
                        .reveal(.rise, 5)

                    Text("Строки, которые уже есть по дате и символу, будут пропущены")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .task {
            if account == nil {
                account = accounts.first
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Журнал")
                ScreenTitle(text: "Импорт из CSV")
                Text("Сделки из MetaTrader, TradingView или своей таблицы")
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

    // MARK: - File

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Файл")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 48, height: 48)
                    Image(systemName: "doc.text")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(fileName ?? "Файл не выбран")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(fileMeta.isEmpty ? "Дата, символ, вход, стоп, тейк, результат, R" : fileMeta)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                Button {
                    showFileImporter()
                } label: {
                    Text("Выбрать файл")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Columns

    private func mappingCard(_ title: String, value: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 96, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

            ZStack {
                Circle()
                    .fill(ok ? Theme.green : Theme.textTertiary.opacity(0.4))
                    .frame(width: 18, height: 18)
                Image(systemName: ok ? "checkmark" : "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func columnsCard(_ first: CSVImportRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Колонки")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            mappingCard("Дата", value: dateText(first.date), ok: true)
            mappingCard("Символ", value: first.symbol, ok: true)
            mappingCard("Направление", value: first.direction.rawValue, ok: true)
            mappingCard("Вход", value: Fmt.price(first.entry), ok: first.entry > 0)
            mappingCard("Стоп", value: Fmt.price(first.stop), ok: first.stop > 0)
            mappingCard("Тейк", value: first.take > 0 ? Fmt.price(first.take) : "—", ok: first.take > 0)
            mappingCard("Результат", value: first.result.rawValue, ok: true)
            mappingCard("R", value: Fmt.r(first.actualR), ok: true)
            mappingCard(
                "Риск",
                value: first.riskUSD > 0 ? Fmt.money(first.riskUSD) : "—",
                ok: first.riskUSD > 0
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Предпросмотр")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text("Первые \(min(3, rows.count)) строки")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.prefix(3).enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 8) {
                        Text(Fmt.shortDay(row.date) + " " + Fmt.time(row.date))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(row.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 76, alignment: .leading)

                        Text(row.result.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tintFor(row.result))
                            .frame(width: 40, alignment: .leading)

                        Text(Fmt.r(row.actualR))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rColor(row.actualR))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, 9)

                    if index < min(3, rows.count) - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassCard(cornerRadius: 18)
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Счёт")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Menu {
                Button {
                    account = nil
                    Haptics.select()
                } label: {
                    if account == nil {
                        Label("Без счёта", systemImage: "checkmark")
                    } else {
                        Text("Без счёта")
                    }
                }

                ForEach(accounts) { item in
                    Button {
                        account = item
                        Haptics.tap()
                    } label: {
                        if account?.persistentModelID == item.persistentModelID {
                            Label("\(item.name) · \(item.type.rawValue)", systemImage: "checkmark")
                        } else {
                            Text("\(item.name) · \(item.type.rawValue)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(accountTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Result and action

    private var resultCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.green)

            Text("Добавлено \(added) \(Fmt.dealWord(added)) · пропущено \(skipped)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var importButton: some View {
        Button {
            importNow()
        } label: {
            Text("Импортировать")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(rows.isEmpty)
        .opacity(rows.isEmpty ? 0.45 : 1)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func showFileImporter() {
        errorText = nil
        showImporter = true
        Haptics.tap()
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let text = try CSVImport.readText(from: url)
                let parsed = try CSVImport.parse(text: text)
                rows = parsed
                fileName = url.lastPathComponent
                fileMeta = metaText(url, count: parsed.count)
                didImport = false
                added = 0
                skipped = 0
                errorText = nil
                Haptics.success()
            } catch {
                rows = []
                fileName = url.lastPathComponent
                fileMeta = ""
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? "Не удалось разобрать файл."
                Haptics.warning()
            }

        case .failure:
            errorText = "Файл не выбран."
            Haptics.warning()
        }
    }

    private func importNow() {
        guard !rows.isEmpty else { return }

        let result = CSVImport.importRows(rows, account: account, context: context)
        added = result.added
        skipped = result.skipped
        didImport = true

        if result.added > 0 {
            Haptics.success()
        } else {
            Haptics.warning()
        }
    }

    // MARK: - Text helpers

    private func metaText(_ url: URL, count: Int) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(values?.fileSize ?? 0),
            countStyle: .file
        )
        let word: String
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 {
            word = "строк"
        } else if mod10 == 1 {
            word = "строка"
        } else if mod10 >= 2 && mod10 <= 4 {
            word = "строки"
        } else {
            word = "строк"
        }
        return "\(size) · \(count) \(word)"
    }

    private func dateText(_ date: Date) -> String {
        "\(Fmt.shortDay(date)) \(Fmt.time(date))"
    }

    private var accountTitle: String {
        guard let account else { return "Без счёта" }
        return "\(account.name) · \(account.type.rawValue)"
    }

    private func tintFor(_ result: TradeResult) -> Color {
        switch result {
        case .tp: return Theme.green
        case .sl: return Theme.red
        case .be: return Theme.orange
        case .open: return Theme.textSecondary
        }
    }

    private func rColor(_ value: Double) -> Color {
        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }
}

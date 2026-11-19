//
//  AssistantLocal.swift
//  ICT Checklist
//
//  Собственный ассистент приложения: считает ответ по базе на устройстве,
//  без внешних моделей, ключей и интернета.
//

import Foundation
import SwiftData

enum AssistantLocal {
    static func answer(to prompt: String, context: ModelContext) -> String {
        let snapshot = Snapshot(context: context)
        let text = prompt.lowercased()

        if matches(text, ["привет", "здравств", "что умеешь", "помощь"]) {
            return capabilities(snapshot)
        }
        if matches(text, ["банк", "валют", "дкп", "ставк", "ставок", "доллар", "евро", "фунт", "макро", "дкп"]) {
            return banks(snapshot)
        }
        if matches(text, ["наруша", "дисципли", "чек-лист", "чеклист", "по системе", "соблюда"]) {
            return discipline(snapshot)
        }
        if matches(text, ["улучш", "скорректир", "скоррект", "менять", "изменить", "изменени"]) {
            return improvement(snapshot)
        }
        if matches(text, ["риск", "лэддер", "лэдер", "лимит", "просадк", "risk"]) {
            return risk(snapshot)
        }
        if matches(text, ["план", "недел"]) {
            return plans(snapshot)
        }
        if matches(text, ["сдел", "разбери", "журнал", "результат"]) {
            return trades(snapshot)
        }
        if matches(text, ["fvg", "snr", "premium", "discount", "delivery", "order flow", "inducement", "idm", "точка a", "точка b", "стоп", "тейк", " rr", "rr "]) {
            return glossary(text)
        }
        if matches(text, ["ошибк", "ошибок"]) {
            return errors(snapshot)
        }
        if matches(text, ["заметк", "second brain", "база знаний", "наблюдени"]) {
            return notes(snapshot)
        }
        if matches(text, ["портфел", "счёт", "счет", "капитал", "баланс"]) {
            return accounts(snapshot)
        }
        return capabilities(snapshot)
    }

    // MARK: - Snapshot

    struct Snapshot {
        let trades: [Trade]
        let plans: [TradePlan]
        let errors: [ErrorNote]
        let notes: [BrainNote]
        let accounts: [TradingAccount]
        let settings: AppSettings?
        let ladder: RiskLadderState?

        init(context: ModelContext) {
            trades = (try? context.fetch(
                FetchDescriptor<Trade>(sortBy: [SortDescriptor(\Trade.entryDate, order: .reverse)])
            )) ?? []
            plans = (try? context.fetch(
                FetchDescriptor<TradePlan>(sortBy: [SortDescriptor(\TradePlan.day, order: .reverse)])
            )) ?? []
            errors = (try? context.fetch(
                FetchDescriptor<ErrorNote>(sortBy: [SortDescriptor(\ErrorNote.updatedAt, order: .reverse)])
            )) ?? []
            notes = (try? context.fetch(
                FetchDescriptor<BrainNote>(sortBy: [SortDescriptor(\BrainNote.updatedAt, order: .reverse)])
            )) ?? []
            accounts = (try? context.fetch(FetchDescriptor<TradingAccount>())) ?? []
            settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
            ladder = (try? context.fetch(FetchDescriptor<RiskLadderState>()))?.first
        }

        var closed: [Trade] { trades.filter { $0.result != .open } }
        var open: [Trade] { trades.filter { $0.result == .open } }

        var totalR: Double { closed.reduce(0) { $0 + $1.actualR } }
        var wins: Int { closed.filter { $0.actualR > 0.05 }.count }

        var winRate: Int {
            closed.isEmpty ? 0 : Int((Double(wins) / Double(closed.count) * 100).rounded())
        }

        var averageR: Double {
            closed.isEmpty ? 0 : totalR / Double(closed.count)
        }

        var bySystem: Int { closed.filter { $0.checklistComplete }.count }

        var disciplineShare: Int {
            closed.isEmpty ? 0 : Int((Double(bySystem) / Double(closed.count) * 100).rounded())
        }

        var missingReviews: Int { closed.filter { $0.review == nil }.count }

        var openRisk: Double { open.reduce(0) { $0 + $1.riskUSD } }

        var capital: Double {
            accounts.filter { !$0.isArchived }.reduce(0) { $0 + $1.balance }
        }

        var openRiskPercent: Double {
            guard capital > 0 else { return 0 }
            return openRisk / capital * 100
        }

        func bySymbol() -> [(String, Int, Double)] {
            Dictionary(grouping: closed, by: \.symbol)
                .map { ($0.key, $0.value.count, $0.value.reduce(0) { $0 + $1.actualR }) }
                .sorted { $0.2 > $1.2 }
        }

        var lossStreak: Int {
            var streak = 0
            for trade in closed {
                if trade.actualR < -0.05 {
                    streak += 1
                } else {
                    break
                }
            }
            return streak
        }
    }

    // MARK: - Trades

    private static func trades(_ s: Snapshot) -> String {
        guard !s.trades.isEmpty else {
            return format(
                verdict: "В базе ещё нет сделок, разбирать нечего.",
                facts: ["Сделок: 0", "Закрытых: 0"],
                actions: [
                    "Запишите первую сделку через кнопку «Новая сделка».",
                    "Отметьте чек-лист сделки, чтобы статистика делилась на «по системе» и «вне системы»."
                ],
                invalidation: "Вывод изменится, когда появится хотя бы 10–15 закрытых сделок."
            )
        }

        var facts: [String] = []
        facts.append("Сделок: \(s.trades.count) · закрытых \(s.closed.count) · открытых \(s.open.count)")
        facts.append("Winrate: \(s.winRate)% · сумма \(Fmt.r(s.totalR)) · средняя \(String(format: "%+.2f", s.averageR))R")
        facts.append("Чек-лист закрыт у \(s.bySystem) из \(s.closed.count) — дисциплина \(s.disciplineShare)%")

        let symbols = s.bySymbol()
        if let best = symbols.first {
            facts.append("Лучший инструмент: \(best.0) — \(best.1) сделок, \(Fmt.r(best.2))")
        }
        if let worst = symbols.last, symbols.count > 1 {
            facts.append("Худший инструмент: \(worst.0) — \(worst.1) сделок, \(Fmt.r(worst.2))")
        }
        for trade in s.trades.prefix(5) {
            var line = "\(Fmt.dayMonth(trade.tradingDay)) \(trade.symbol) \(trade.direction.rawValue) \(trade.result.rawValue) \(Fmt.r(trade.actualR))"
            if !trade.checklistComplete {
                line += " · вне системы"
            }
            facts.append(line)
        }

        var actions: [String] = []
        if s.disciplineShare < 80, s.closed.count >= 5 {
            actions.append("Сначала дисциплина: \(100 - s.disciplineShare)% закрытых сделок прошли без полного чек-листа. Отделите их в статистике.")
        }
        if s.missingReviews > 0 {
            actions.append("Заполните разбор у \(s.missingReviews) сделок: без него ошибки не видны.")
        }
        if let worst = symbols.last, symbols.count > 1, worst.2 < 0 {
            actions.append("Проверьте \(worst.0): суммарно \(Fmt.r(worst.2)). Либо сетап не подходит инструменту, либо вход без валидации.")
        }
        if actions.isEmpty {
            actions.append("Держите текущий процесс: сделки по системе, риск со ступени, разбор после закрытия.")
        }

        return format(
            verdict: "Результат \(Fmt.r(s.totalR)) на \(s.closed.count) закрытых сделках, winrate \(s.winRate)%.",
            facts: facts,
            actions: actions,
            invalidation: "Если следующие 20 сделок дадут среднюю ниже \(String(format: "%+.2f", s.averageR))R, это уже не дисперсия — проверяйте сетап."
        )
    }

    // MARK: - Discipline

    private static func discipline(_ s: Snapshot) -> String {
        let outside = s.closed.count - s.bySystem
        var facts: [String] = [
            "Закрытых сделок: \(s.closed.count)",
            "С полным чек-листом: \(s.bySystem) · вне системы: \(outside)",
            "Дисциплина: \(s.disciplineShare)%"
        ]
        if s.missingReviews > 0 {
            facts.append("Без разбора: \(s.missingReviews)")
        }
        let incompletePlans = s.plans.filter { !$0.isChecklistComplete }.count
        if !s.plans.isEmpty {
            facts.append("Планы: \(s.plans.count), неполный чек-лист у \(incompletePlans)")
        }

        var actions: [String] = []
        if outside > 0 {
            actions.append("Перестаньте смешивать: считайте отдельно статистику сделок по системе и вне её.")
        }
        if incompletePlans > 0 {
            actions.append("Доведите чек-лист плана до конца до входа, а не после.")
        }
        if s.missingReviews > 0 {
            actions.append("Закройте разборы: \(s.missingReviews) сделок без разбора — это неизмеренные ошибки.")
        }
        if actions.isEmpty {
            actions.append("Дисциплина в норме: продолжайте отмечать чек-лист под каждую сделку.")
        }

        return format(
            verdict: outside == 0
                ? "Все закрытые сделки прошли по системе."
                : "\(outside) из \(s.closed.count) закрытых сделок прошли без полного чек-листа.",
            facts: facts,
            actions: actions,
            invalidation: "Если доля по системе упадёт ниже 70%, статистика перестаёт описывать вашу систему."
        )
    }

    // MARK: - Risk

    private static func risk(_ s: Snapshot) -> String {
        var facts: [String] = []
        if let ladder = s.ladder {
            facts.append("Ступень лэддера: \(min(max(ladder.stepIndex, 0), 2) + 1) из 3 · накоплено \(Fmt.r(ladder.accumulatedR))")
        }
        if let settings = s.settings {
            facts.append("Риск по ступеням: \(Fmt.money(s.settings?.ladder1 ?? 0)) / \(Fmt.money(s.settings?.ladder2 ?? 0)) / \(Fmt.money(s.settings?.ladder3 ?? 0))")
            facts.append("Минимальный RR: \(Fmt.rr(settings.minRR)) · лимит риска на сделку \(String(format: "%.1f", settings.maxRiskPercent))% капитала")
            if settings.dailyLimitsEnabled {
                facts.append("Лимиты дня: \(settings.maxTradesPerDay) сделок, убыток до \(Fmt.r(-settings.maxDailyLossR))")
            } else {
                facts.append("Лимиты дня выключены")
            }
        }
        facts.append("Открытых сделок: \(s.open.count) · открытый риск \(Fmt.money(s.openRisk)) (\(String(format: "%.1f", s.openRiskPercent))% капитала)")
        if s.lossStreak > 0 {
            facts.append("Текущая серия убытков: \(s.lossStreak)")
        }

        var actions: [String] = []
        if s.lossStreak >= 2 {
            actions.append("Серия из \(s.lossStreak) убытков — не повышайте риск и проверьте, не нарушался ли чек-лист.")
        }
        if s.openRiskPercent > (s.settings?.maxRiskPercent ?? 1) * 3 {
            actions.append("Открытый риск \(String(format: "%.1f", s.openRiskPercent))% капитала выше разумного: новые входы не добавляйте.")
        }
        if s.settings?.dailyLimitsEnabled == false {
            actions.append("Включите дневные лимиты: без них один день может снять результат недели.")
        }
        if actions.isEmpty {
            actions.append("Риск в норме: держите размер со ступени и не увеличивайте после убытка.")
        }

        return format(
            verdict: "Открытый риск \(String(format: "%.1f", s.openRiskPercent))% капитала, серия убытков \(s.lossStreak).",
            facts: facts,
            actions: actions,
            invalidation: "Если серия убытков дойдёт до 3 при полном соблюдении системы, уменьшите риск на ступень."
        )
    }

    // MARK: - Improvement

    private static func improvement(_ s: Snapshot) -> String {
        var facts: [String] = []
        facts.append("Закрытых сделок для анализа: \(s.closed.count)")
        facts.append("Winrate \(s.winRate)% · средняя \(String(format: "%+.2f", s.averageR))R · дисциплина \(s.disciplineShare)%")
        let incompletePlans = s.plans.filter { !$0.isChecklistComplete }.count
        if !s.plans.isEmpty {
            facts.append("Планы с неполным чек-листом: \(incompletePlans) из \(s.plans.count)")
        }
        if s.missingReviews > 0 {
            facts.append("Без разбора: \(s.missingReviews)")
        }
        let repeated = s.errors.filter { $0.status == .repeated }
        if !repeated.isEmpty {
            facts.append("Повторяющихся ошибок: \(repeated.count)")
        }

        var hypothesis: String
        var measure: String
        if s.closed.count < 20 {
            hypothesis = "Сначала наберите выборку: 20–30 сделок с полным чек-листом, иначе любое изменение будет подгонкой."
            measure = "Считаем winrate, средний R и долю сделок по системе на этой выборке."
        } else if s.disciplineShare < 70 {
            hypothesis = "Одно изменение: не брать сделку без полностью закрытого чек-листа."
            measure = "Через 20 сделок сравните средний R и просадку у сделок по системе и вне её."
        } else if s.winRate < 40, s.averageR < 0 {
            hypothesis = "Одно изменение: ограничить работу одним сетапом с лучшим вкладом, остальные поставить на паузу."
            measure = "Через 20 сделок сравните средний R этого сетапа с общим результатом."
        } else {
            hypothesis = "Одно изменение: зафиксировать текущий риск и добавить разбор каждой сделки в течение суток."
            measure = "Через месяц сравните средний R и число повторяющихся ошибок."
        }

        return format(
            verdict: "Меняем один элемент системы и измеряем его на 20–30 сделках.",
            facts: facts,
            actions: [
                "Гипотеза: \(hypothesis)",
                "Измерение: \(measure)",
                "Запишите это в Second Brain как гипотезу, чтобы потом проверить."
            ],
            invalidation: "Если за период измерения средний R ухудшился, изменение откатываем. Больше одного изменения за раз не делаем."
        )
    }

    // MARK: - Banks

    private static func banks(_ s: Snapshot) -> String {
        var facts: [String] = []
        for profile in CapitalFlows.allProfiles {
            facts.append(
                "\(profile.region.currency) · \(profile.policy.bank) · \(profile.biasTitle). Ставка \(profile.policy.metrics.policyRate). Ожидания: \(profile.policy.expected.direction.lowercased()), через месяц — \(profile.policy.expected.oneMonth)"
            )
            facts.append("\(profile.region.currency) · расхождение: \(profile.policy.divergenceTitle). Сила валюты: \(profile.policy.bias.label). \(profile.policy.currencyEffect)")
        }
        facts.append("Окно ребаланса: \(CapitalFlows.rebalancingWindow().label)")

        let strongest = CapitalFlows.allProfiles.max { $0.policy.bias.score < $1.policy.bias.score }
        let weakest = CapitalFlows.allProfiles.min { $0.policy.bias.score < $1.policy.bias.score }

        return format(
            verdict: "Фундаментально сильнее \(strongest?.region.currency ?? "USD"), слабее \(weakest?.region.currency ?? "GBP"): разница в ставке и ожиданиях.",
            facts: facts,
            actions: [
                "Смотрите на расхождение ожиданий, а не на саму ставку: движение даёт смена ожиданий.",
                "В конце месяца и квартала учитывайте ребаланс фондов — он может перебить новостную логику.",
                "Перед входом сверьте ставки и риторику с календарём ЦБ: данные в приложении — ориентир."
            ],
            invalidation: "Смена риторики банка на ястребиную или мягкую переворачивает вывод быстрее, чем сами ставки."
        )
    }

    // MARK: - Plans

    private static func plans(_ s: Snapshot) -> String {
        guard !s.plans.isEmpty else {
            return format(
                verdict: "Планов пока нет.",
                facts: ["Планов: 0", "Открытых сделок: \(s.open.count)"],
                actions: [
                    "Создайте план на сделку в разделе «Сделки» → «Планы».",
                    "Пройдите чек-лист плана до конца, прежде чем входить."
                ],
                invalidation: "Вывод изменится, когда появится хотя бы один завершённый план."
            )
        }

        var facts: [String] = []
        for plan in s.plans.prefix(4) {
            facts.append(
                "\(Fmt.dayMonth(plan.day)) \(plan.symbol) \(plan.direction.rawValue) — \(plan.result.rawValue) · чек-лист \(plan.checkedCount)/\(PlanCheck.allCases.count)"
            )
        }
        facts.append("Всего планов: \(s.plans.count) · с неполным чек-листом: \(s.plans.filter { !$0.isChecklistComplete }.count)")

        return format(
            verdict: "Последние планы: \(s.plans.prefix(2).map { $0.symbol }.joined(separator: ", ")).",
            facts: facts,
            actions: [
                "Доводите чек-лист плана до 100% до входа, а не после.",
                "Не переносите план между днями без новой проверки контекста.",
                "Связывайте план со сделкой: тогда видно, где план и факт разошлись."
            ],
            invalidation: "Если планы с неполным чек-листом дают лучший R, значит чек-лист перегружен — его надо менять."
        )
    }

    // MARK: - Errors

    private static func errors(_ s: Snapshot) -> String {
        guard !s.errors.isEmpty else {
            return format(
                verdict: "Ошибок в книге нет.",
                facts: ["Записей об ошибках: 0"],
                actions: ["Записывайте повторяющиеся ошибки: цена ошибки в R видна только на истории."],
                invalidation: "Вывод изменится после первой записанной ошибки с привязанными сделками."
            )
        }

        let repeated = s.errors.filter { $0.status == .repeated }
        let expensive = s.errors.max { lhs, rhs in
            lhs.trades.reduce(0) { $0 + $1.actualR } < rhs.trades.reduce(0) { $0 + $1.actualR }
        }

        var facts: [String] = ["Всего ошибок: \(s.errors.count) · повторяющихся \(repeated.count)"]
        for note in s.errors.prefix(4) {
            let cost = note.trades.reduce(0) { $0 + $1.actualR }
            facts.append("\(note.title) [\(note.status.rawValue)] · \(note.trades.count) сделок · \(Fmt.r(cost))")
        }
        if let expensive {
            facts.append("Самая дорогая: \(expensive.title) — \(Fmt.r(expensive.trades.reduce(0) { $0 + $1.actualR }))")
        }

        return format(
            verdict: repeated.isEmpty
                ? "Повторяющихся ошибок нет, но книга ошибок ведётся."
                : "Есть \(repeated.count) повторяющихся ошибок — это дороже единичного убытка.",
            facts: facts,
            actions: [
                "Возьмите одну повторяющуюся ошибку и добавьте её в чек-лист перед входом.",
                "Через 10 сделок проверьте, исчезла ли она.",
                "Ошибки без сделок не считаются: привязывайте сделки, где ошибка проявилась."
            ],
            invalidation: "Если ошибка повторяется и после добавления в чек-лист, она в чек-листе описана слишком мягко."
        )
    }

    // MARK: - Notes

    private static func notes(_ s: Snapshot) -> String {
        guard !s.notes.isEmpty else {
            return format(
                verdict: "База знаний пуста.",
                facts: ["Записей: 0"],
                actions: [
                    "Начните с наблюдения за рынком: что повторяется в ваших сделках.",
                    "Совет ассистента можно сохранить кнопкой «В Second Brain»."
                ],
                invalidation: "Вывод изменится после первой записи."
            )
        }

        var facts: [String] = ["Записей: \(s.notes.count)"]
        for note in s.notes.prefix(4) {
            facts.append("\(note.kind.short) · \(note.displayTitle)")
        }

        return format(
            verdict: "В базе \(s.notes.count) записей, последняя — «\(s.notes.first?.displayTitle ?? "")».",
            facts: facts,
            actions: [
                "Проверяйте гипотезы на сделках и меняйте их статус.",
                "Связывайте заметки со сделками: так видно, где теория расходится с практикой."
            ],
            invalidation: "Если гипотеза держится больше 30 сделок без подтверждения, её надо менять."
        )
    }

    // MARK: - Accounts

    private static func accounts(_ s: Snapshot) -> String {
        let active = s.accounts.filter { !$0.isArchived }
        guard !active.isEmpty else {
            return format(
                verdict: "Счетов пока нет.",
                facts: ["Счетов: 0", "Сделок: \(s.trades.count)"],
                actions: ["Добавьте счёт в разделе «Счета», чтобы видеть капитал и процент риска."],
                invalidation: "Вывод изменится после создания первого счёта."
            )
        }

        var facts: [String] = [
            "Активных счетов: \(active.count)",
            "Капитал: \(Fmt.money(s.capital))",
            "Открытый риск: \(Fmt.money(s.openRisk)) (\(String(format: "%.1f", s.openRiskPercent))% капитала)"
        ]
        for account in active.prefix(4) {
            facts.append("\(account.name.isEmpty ? account.type.rawValue : account.name) · \(Fmt.money(account.balance))")
        }

        return format(
            verdict: "Капитал \(Fmt.money(s.capital)) на \(active.count) счётах, открытый риск \(String(format: "%.1f", s.openRiskPercent))%.",
            facts: facts,
            actions: [
                "Держите риск на сделку в пределах \(String(format: "%.1f", s.settings?.maxRiskPercent ?? 1))% капитала.",
                "Если открытый риск выше этого, новые входы не добавляйте."
            ],
            invalidation: "Процент риска считается от капитала; при изменении капитала лимит в деньгах меняется."
        )
    }

    // MARK: - Capabilities

    private static func capabilities(_ s: Snapshot) -> String {
        format(
            verdict: "Я собственный ассистент приложения: считаю по вашей базе на устройстве, без ключей и интернета.",
            facts: [
                "Данных сейчас: \(s.trades.count) сделок · \(s.closed.count) закрытых · \(s.plans.count) планов · \(s.notes.count) заметок",
                "Дисциплина по чек-листу: \(s.disciplineShare)%"
            ],
            actions: [
                "Попросите: «Разбери последние сделки», «Где я нарушаю систему», «Что с риском», «Помоги скорректировать систему».",
                "Банковский блок: «Что с валютой: три банка и ставки».",
                "Процесс: «Что по планам», «Что по ошибкам», «Что в заметках»."
            ],
            invalidation: "Ответы точнее, когда есть сделки с закрытым чек-листом и заполненными разборами."
        )
    }

    // MARK: - Glossary

    private static func glossary(_ text: String) -> String {
        let terms: [(String, [String], String)] = [
            ("FVG", ["fvg"], "разрыв между свечами после импульса; цена часто возвращается его закрыть, поэтому это зона интереса по тренду."),
            ("SNR", ["snr"], "поддержка и сопротивление; уровень становится валидным только после реакции и подтверждения на младшем таймфрейме."),
            ("DR", ["dr", "dealing range"], "диапазон между ключевыми свингами после импульса; внутри важны 0.5 DR, premium и discount."),
            ("Premium / discount", ["premium", "discount"], "premium — верхняя половина диапазона, discount — нижняя; лонг ищут в discount, шорт — в premium."),
            ("Delivery", ["delivery", "order flow"], "как цена доставляется к цели; обычный поток допускает коррекции, Strong и True — целевое движение."),
            ("Inducement", ["inducement", "idm"], "ловушка перед зоной интереса: цена снимает ликвидность у ближайшего свинга, поэтому вход лучше после её снятия."),
            ("Точки A и B", ["точка a", "точка b"], "A — ключевой уровень или зона, откуда началось движение; B — следующая цель по структуре; сделка только внутри маршрута A → B."),
            ("Стоп и тейк", ["стоп", "тейк"], "стоп за инвалидацию идеи, а не за ближайший фрактал; тейк по структуре: 0.5 DR, следующий свинг, ребаланс диапазона."),
            ("R и RR", ["rr", " r "], "R — единица риска, +2R значит прибыль в два раза больше риска; RR считается до входа и сравнивается с минимумом из настроек.")
        ]

        var picked: [(String, String)] = []
        for term in terms where matches(text, term.1) {
            picked.append((term.0, term.2))
            if picked.count == 3 { break }
        }

        guard !picked.isEmpty else {
            return format(
                verdict: "Не понял, какой термин разобрать.",
                facts: [],
                actions: ["Уточните термин: FVG, SNR, DR, premium и discount, delivery, inducement, точки A и B, стоп и тейк, R и RR."],
                invalidation: "Ответ изменится, когда будет назван конкретный термин."
            )
        }

        return format(
            verdict: "Термины системы: \(picked.map { $0.0 }.joined(separator: ", ")).",
            facts: picked.map { "\($0.0) — \($0.1)" },
            actions: [
                "Смотрите не на название, а на условие входа: где валидация и где инвалидация.",
                "Переведите термин в проверяемый пункт чек-листа, иначе он не работает."
            ],
            invalidation: "Правило без конкретного условия входа и инвалидации — это описание, а не система."
        )
    }

    // MARK: - Helpers

    private static func matches(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func format(
        verdict: String,
        facts: [String],
        actions: [String],
        invalidation: String
    ) -> String {
        let actionLines = actions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let factBlock = facts.isEmpty ? "— нет данных" : "— " + facts.joined(separator: "\n— ")
        return """
        **ВЫВОД**
        \(verdict)

        **ФАКТЫ**
        \(factBlock)

        **ДЕЙСТВИЯ**
        \(actions.isEmpty ? "— по системе делать нечего, держите процесс." : actionLines)

        **ИНВАЛИДАЦИЯ**
        \(invalidation)
        """
    }
}

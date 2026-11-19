//
//  CapitalFlows.swift
//  ICT Checklist
//
//  Кто и почему двигает валюту: мотив центральных банков,
//  реакция валюты на события, ребалансы фондов, хедж выручки и тренд.
//

import SwiftUI

/// Как валюта отвечает на событие.
enum ReactionDirection {
    case supports
    case pressures
    case neutral

    var title: String {
        switch self {
        case .supports: return "РОСТ"
        case .pressures: return "ПАДЕНИЕ"
        case .neutral: return "НЕЙТРАЛЬНО"
        }
    }

    var symbolName: String {
        switch self {
        case .supports: return "arrow.up.right"
        case .pressures: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    var tint: Color {
        switch self {
        case .supports: return Theme.green
        case .pressures: return Theme.red
        case .neutral: return Theme.textSecondary
        }
    }
}

struct CurrencyReaction: Identifiable {
    var id: String { event }
    let event: String
    let direction: ReactionDirection
    /// Насколько сильно двигает: сильно, умеренно, слабо.
    let strength: String
    let comment: String
}

/// Числовая картина вокруг решения банка.
struct BankMetrics {
    let policyRate: String
    let nextMove: String
    let balanceSheet: String
    let coreInflation: String
    let labour: String
    let growth: String
    let realRate: String
}

/// Ожидаемая траектория ставки на трёх горизонтах.
struct ExpectedPolicy {
    let oneMonth: String
    let quarter: String
    let year: String
    /// Общий вектор: мягче, жёстче, пауза.
    let direction: String
}

/// Фундаментальная сила валюты.
struct CurrencyBias {
    let label: String
    /// −2 сильная слабость, 0 нейтрально, +2 сильная сила.
    let score: Int
    let text: String

    var tint: Color {
        if score >= 1 { return Theme.green }
        if score <= -1 { return Theme.red }
        return Theme.textSecondary
    }
}

struct KeyDateItem: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let cadence: String
}

/// Позиция центрального банка и её следствие для валюты.
struct PolicyStance {
    let bank: String
    /// Где банк находится в цикле ставки.
    let stance: String
    /// Зачем банк так делает.
    let motive: String
    /// Что из этого следует для валюты.
    let currencyEffect: String
    let metrics: BankMetrics
    let reactions: [CurrencyReaction]
    /// Как ведут себя пары и кросс-курсы.
    let pairsNote: String
    let dates: [KeyDateItem]
    /// Что отменит текущий сценарий.
    let invalidation: String
    /// Ожидаемая траектория ставки.
    let expected: ExpectedPolicy
    /// Короткая метка расхождения с другими банками.
    let divergenceTitle: String
    /// Расхождение между банками и его следствие.
    let divergence: String
    /// Фундаментальная сила валюты.
    let bias: CurrencyBias
}

/// Потоки, которые не зависят от того, куда идёт график.
struct FlowProfile {
    let pension: String
    let trade: String
    let trend: String
}

struct CapitalFlowProfile: Identifiable {
    let region: EconomyRegion
    /// Короткая метка курса: пауза, смягчение, осторожное снижение.
    let biasTitle: String
    let tint: Color
    let policy: PolicyStance
    let flows: FlowProfile

    var id: String { region.id }
}

enum CapitalFlows {
    static func profile(for region: EconomyRegion) -> CapitalFlowProfile {
        switch region {
        case .usa:
            return CapitalFlowProfile(
                region: .usa,
                biasTitle: "Пауза в цикле смягчения",
                tint: Theme.green,
                policy: PolicyStance(
                    bank: "ФРС",
                    stance: "Смягчение с паузами: ставка остаётся высокой дольше, чем ждал рынок.",
                    motive: "Инфляция всё ещё выше цели, а рынок труда остывает. ФРС держит ставку, чтобы не потерять доверие к цели 2% и не смягчить условия раньше времени.",
                    currencyEffect: "Пауза и жёсткая риторика поддерживают доллар. Возобновление снижения или намёк на него давят на доллар, особенно против евро и иены.",
                    metrics: BankMetrics(
                        policyRate: "3,75–4,00% · ориентир",
                        nextMove: "рынок оценивает паузу, следующий шаг — снижение",
                        balanceSheet: "QT продолжается, баланс сокращается",
                        coreInflation: "базовая выше цели, услуги тормозят",
                        labour: "рынок труда остывает без резкого роста безработицы",
                        growth: "рост замедляется, потребитель держится",
                        realRate: "реальная ставка около +1,5% — жёсткая"
                    ),
                    reactions: [
                        CurrencyReaction(
                            event: "Пауза и жёсткая риторика",
                            direction: .supports,
                            strength: "сильно",
                            comment: "Доллар укрепляется шире рынка: EUR/USD и GBP/USD теряют 40–70 пунктов за сессию."
                        ),
                        CurrencyReaction(
                            event: "Намёк на снижение",
                            direction: .pressures,
                            strength: "сильно",
                            comment: "Доллар слабеет против евро и иены; carry-позиции в долларе закрываются."
                        ),
                        CurrencyReaction(
                            event: "Горячий CPI",
                            direction: .supports,
                            strength: "умеренно",
                            comment: "Ставка выше дольше — рынок пересматривает траекторию, доллар растёт."
                        ),
                        CurrencyReaction(
                            event: "Слабые payrolls",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Ожидания снижения растут быстрее, чем инфляция, — давление на доллар."
                        ),
                        CurrencyReaction(
                            event: "Risk-off на рынках",
                            direction: .supports,
                            strength: "сильно",
                            comment: "Спрос на Treasuries и долларовую ликвидность перебивает всё остальное."
                        ),
                        CurrencyReaction(
                            event: "Падение доходностей",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Спред к остальным ставкам сужается, carry сжимается."
                        )
                    ],
                    pairsNote: "Основные каналы — EUR/USD и GBP/USD. В risk-off доллар растёт против обеих валют, даже если данных по США нет. USD/JPY чувствителен к разнице доходностей сильнее всех.",
                    dates: [
                        KeyDateItem(title: "Заседание FOMC", cadence: "8 раз в год, обычно среда"),
                        KeyDateItem(title: "CPI", cadence: "середина месяца"),
                        KeyDateItem(title: "Payrolls", cadence: "первая пятница месяца"),
                        KeyDateItem(title: "PCE и прогнозы", cadence: "конец месяца, прогнозы раз в квартал")
                    ],
                    invalidation: "Сценарий паузы ломается, если инфляция ускоряется два месяца подряд — рынок начнёт закладывать повышение, и доллар получит второй импульс.",
                    expected: ExpectedPolicy(
                        oneMonth: "Через месяц рынок почти не закладывает изменений: пауза с жёсткой риторикой.",
                        quarter: "Через квартал — риск одного снижения, если инфляция продолжит остывать.",
                        year: "Через год базовая траектория — два-три снижения, ставка ближе к нейтральной.",
                        direction: "Мягче, но медленно"
                    ),
                    divergenceTitle: "Спред в пользу доллара",
                    divergence: "ФРС стоит выше остальных по ставке и реальному проценту. Даже когда она начинает снижаться, спред в пользу доллара остаётся положительным, а расхождение с ЕЦБ — самое широкое из трёх пар. Это главный топливный поток для carry в USD.",
                    bias: CurrencyBias(
                        label: "Сильный",
                        score: 2,
                        text: "Жёсткая реальная ставка, спрос на Treasuries и убежище в risk-off держат доллар сильнее остальных. Риск для силы — быстрое смягчение и рост дефицита бюджета."
                    )
                ),
                flows: FlowProfile(
                    pension: "Квартальный и месячный ребаланс приходится на последние дни периода. Если акции выросли, фонды продают их и докупают облигации — растёт спрос на доллары. В слабом квартале эффект обратный и слабее.",
                    trade: "Экспортёры и корпорации с зарубежной выручкой хеджируют 50–80% на 3–12 месяцев вперёд. Это постоянный поток: иностранная выручка продаётся за доллары независимо от того, куда идёт цена.",
                    trend: "Трендовые фонды добавляют в сторону подтверждённого тренда и хеджируют позицию. В тренде это топливо, на развороте — ускоренное закрытие."
                )
            )
        case .uk:
            return CapitalFlowProfile(
                region: .uk,
                biasTitle: "Осторожное снижение",
                tint: Theme.orange,
                policy: PolicyStance(
                    bank: "Банк Англии",
                    stance: "Осторожное снижение: инфляция услуг тормозит быстрые шаги.",
                    motive: "Инфляция услуг выше цели, а рост слабый. Банк балансирует между поддержкой экономики и риском закрепить инфляцию.",
                    currencyEffect: "Осторожность поддерживает фунт, особенно на сильных данных по зарплатам. Ускорение снижения давит на фунт.",
                    metrics: BankMetrics(
                        policyRate: "4,00% · ориентир",
                        nextMove: "рынок закладывает ещё одно снижение до конца года",
                        balanceSheet: "QT продолжается, продажи gilts идут",
                        coreInflation: "инфляция услуг выше 5% — главный тормоз",
                        labour: "зарплаты растут быстрее, чем хотелось бы банку",
                        growth: "рост почти нулевой, промышленность слабая",
                        realRate: "реальная ставка около +0,5% — умеренно жёсткая"
                    ),
                    reactions: [
                        CurrencyReaction(
                            event: "Пауза вместо снижения",
                            direction: .supports,
                            strength: "сильно",
                            comment: "Фунт — тонкий рынок: GBP/USD может пройти 80–120 пунктов за час."
                        ),
                        CurrencyReaction(
                            event: "Снижение на заседании",
                            direction: .pressures,
                            strength: "сильно",
                            comment: "Спред к США сужается, carry уходит, фунт слабеет против доллара и евро."
                        ),
                        CurrencyReaction(
                            event: "Горячий CPI услуг",
                            direction: .supports,
                            strength: "умеренно",
                            comment: "Рынок сдвигает следующее снижение дальше — фунт получает поддержку."
                        ),
                        CurrencyReaction(
                            event: "Слабые payrolls",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Экономика слабеет, банк ускоряет снижение — давление на фунт."
                        ),
                        CurrencyReaction(
                            event: "Risk-off на рынках",
                            direction: .pressures,
                            strength: "сильно",
                            comment: "Фунт ведёт себя как риск-актив: падает против доллара сильнее евро."
                        ),
                        CurrencyReaction(
                            event: "Рост доходностей gilts",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "LDI-фонды продают активы и покупают доллары для маржи — фунт под давлением."
                        )
                    ],
                    pairsNote: "GBP/USD чувствителен к спреду ставок с США, EUR/GBP — к разнице ожиданий Банка Англии и ЕЦБ. В risk-off фунт падает быстрее евро, поэтому EUR/GBP растёт.",
                    dates: [
                        KeyDateItem(title: "Заседание MPC", cadence: "8 раз в год, обычно четверг"),
                        KeyDateItem(title: "CPI", cadence: "середина месяца"),
                        KeyDateItem(title: "Средняя зарплата", cadence: "вторник, ежемесячно"),
                        KeyDateItem(title: "ВВП", cadence: "раз в квартал")
                    ],
                    invalidation: "Сценарий осторожного снижения ломается, если инфляция услуг резко замедлится: банк пойдёт быстрее, и фунт потеряет поддержку.",
                    expected: ExpectedPolicy(
                        oneMonth: "Через месяц — пауза: рынок ждёт данных по инфляции услуг.",
                        quarter: "Через квартал — одно снижение на 25 б.п., если услуги замедлятся.",
                        year: "Через год ставка ниже текущей примерно на 0,5–0,75 п.п., но остаётся выше нейтральной.",
                        direction: "Мягче"
                    ),
                    divergenceTitle: "Спред к США сужается",
                    divergence: "Фунт живёт на спреде к США: пока ФРС держит паузу, а Банк Англии снижает, разница сжимается и carry уходит. С ЕЦБ спред почти нулевой, поэтому EUR/GBP двигают данные, а не ставки.",
                    bias: CurrencyBias(
                        label: "Умеренно слабый",
                        score: -1,
                        text: "Слабый рост, инфляция услуг и зависимость от импорта энергии давят на фунт. Поддержка только от осторожности банка и высоких зарплат."
                    )
                ),
                flows: FlowProfile(
                    pension: "LDI-фонды чувствительны к доходности gilts: при падении доходностей они покупают облигации, при росте — продают. Ребаланс в конце месяца и квартала даёт заметный, но короткоживущий поток.",
                    trade: "Британия импортирует энергию и товары, поэтому хедж импорта — структурный спрос на доллар. Экспортёры хеджируют выручку — это обратный поток в фунт.",
                    trend: "Фунт — тонкий рынок: трендовые потоки дают резкие движения и ложные пробои на концах сессий."
                )
            )
        case .europe:
            return CapitalFlowProfile(
                region: .europe,
                biasTitle: "Смягчение у завершения",
                tint: Theme.lavender,
                policy: PolicyStance(
                    bank: "ЕЦБ",
                    stance: "Ставка около нейтральной, цикл смягчения близок к завершению.",
                    motive: "Слабый рост и промышленность против инфляции услуг. ЕЦБ не хочет чрезмерного укрепления евро, которое давит на экспорт и создаёт дефляционный импорт.",
                    currencyEffect: "Пауза и осторожная риторика удерживают евро. Дальнейшее снижение давит на евро, а слишком быстрое укрепление — повод для словесного вмешательства.",
                    metrics: BankMetrics(
                        policyRate: "2,00% по депозитам · ориентир",
                        nextMove: "рынок оценивает паузу, риск ещё одного снижения не снят",
                        balanceSheet: "сокращение баланса идёт постепенно",
                        coreInflation: "инфляция услуг около 3%, общая у цели",
                        labour: "рынок труда крепкий, зарплаты не ускоряются",
                        growth: "промышленность слабая, услуги тянут",
                        realRate: "реальная ставка около 0% — нейтральная"
                    ),
                    reactions: [
                        CurrencyReaction(
                            event: "Пауза и нейтральная риторика",
                            direction: .supports,
                            strength: "умеренно",
                            comment: "Евро держится, EUR/USD остаётся в диапазоне до новых данных."
                        ),
                        CurrencyReaction(
                            event: "Ещё одно снижение",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Спред к США расширяется, евро слабеет против доллара."
                        ),
                        CurrencyReaction(
                            event: "Слабая промышленность и PMI",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Рынок закладывает более быстрое смягчение — давление на евро."
                        ),
                        CurrencyReaction(
                            event: "Быстрое укрепление евро",
                            direction: .pressures,
                            strength: "слабо",
                            comment: "Риск словесного вмешательства: чиновники начинают говорить о вреде сильного евро."
                        ),
                        CurrencyReaction(
                            event: "Горячая инфляция услуг",
                            direction: .supports,
                            strength: "умеренно",
                            comment: "Пауза становится дольше, евро получает поддержку против доллара."
                        ),
                        CurrencyReaction(
                            event: "Risk-off на рынках",
                            direction: .pressures,
                            strength: "умеренно",
                            comment: "Доллар как убежище сильнее: EUR/USD тянется вниз, даже при спокойных данных."
                        )
                    ],
                    pairsNote: "EUR/USD — самый ликвидный инструмент, реакция на события США часто сильнее, чем на европейские. EUR/GBP реагирует на разницу ожиданий ЕЦБ и Банка Англии.",
                    dates: [
                        KeyDateItem(title: "Заседание ЕЦБ", cadence: "каждые 6 недель, четверг"),
                        KeyDateItem(title: "Flash CPI", cadence: "конец месяца"),
                        KeyDateItem(title: "PMI", cadence: "первое число месяца"),
                        KeyDateItem(title: "Прогнозы персонала", cadence: "раз в квартал")
                    ],
                    invalidation: "Сценарий паузы ломается при возобновлении роста инфляции услуг: рынок уберёт ожидание снижения, и евро укрепится, а экспортёры начнут давить на банк.",
                    expected: ExpectedPolicy(
                        oneMonth: "Через месяц — пауза, новых сигналов нет.",
                        quarter: "Через квартал — риск ещё одного снижения на 25 б.п. при слабых PMI.",
                        year: "Через год ставка около нейтральной, дальнейшее смягчение ограничено.",
                        direction: "Пауза с риском снижения"
                    ),
                    divergenceTitle: "Спред против евро",
                    divergence: "ЕЦБ ниже ФРС и близок к нейтральной ставке, поэтому спред работает против евро. Но если ФРС начнёт снижаться быстрее, расхождение сократится — это и есть главный драйвер EUR/USD.",
                    bias: CurrencyBias(
                        label: "Нейтральный",
                        score: 0,
                        text: "Слабый рост против крепкого рынка труда и профицита счёта текущих операций. Евро держится не силой экономики, а слабостью доллара и ожиданиями по ставкам."
                    )
                ),
                flows: FlowProfile(
                    pension: "Крупные европейские пенсионные фонды ребалансируют в конце месяца и квартала: покупают облигации и хеджируют валютный риск. Потоки идут в евро и совпадают с концом отчётного периода.",
                    trade: "Германия и экспортёры хеджируют выручку в долларах: постоянная продажа USD и покупка EUR, не зависящая от цены. В конце месяца и квартала поток усиливается.",
                    trend: "EUR/USD — самый ликвидный трендовый инструмент: трендовые фонды добавляют в тренде и резко выходят на развороте."
                )
            )
        }
    }

    /// Все три банка рядом: метка курса и короткий след для валюты.
    static var allProfiles: [CapitalFlowProfile] {
        EconomyRegion.allCases.map { profile(for: $0) }
    }

    /// Окно ребаланса: последние дни месяца и квартала.
    static func rebalancingWindow(for date: Date = .now) -> (label: String, active: Bool) {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return ("Вне окна ребаланса", false)
        }
        let lastDay = range.count
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)

        if isEndOfQuarterMonth(month), day >= lastDay - 6 {
            return ("Окно квартального ребаланса", true)
        }
        if day >= lastDay - 3 {
            return ("Окно месячного ребаланса", true)
        }
        return ("Вне окна ребаланса", false)
    }

    private static func isEndOfQuarterMonth(_ month: Int) -> Bool {
        [3, 6, 9, 12].contains(month)
    }
}

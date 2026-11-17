//
//  Achievements.swift
//  ICT Checklist
//

import Foundation

struct AchievementItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let value: String
    let caption: String
    let progress: Double?
    let isAchieved: Bool
}

enum Achievements {
    static func items(trades: [Trade], goals: [MonthlyGoal]) -> [AchievementItem] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let closed = trades.filter { $0.result != .open }

        // MARK: Day totals

        struct DayStat {
            var r: Double = 0
            var hasSL = false
        }

        var dayMap: [Date: DayStat] = [:]
        for trade in closed {
            let day = calendar.startOfDay(for: trade.tradingDay)
            var stat = dayMap[day] ?? DayStat()
            stat.r += trade.actualR
            if trade.result == .sl { stat.hasSL = true }
            dayMap[day] = stat
        }
        let days = dayMap.keys.sorted()

        // MARK: Week totals

        var weekR: [Date: Double] = [:]
        var weekWins: [Date: Int] = [:]
        var weekCounts: [Date: Int] = [:]
        var monthR: [Date: Double] = [:]

        for trade in closed {
            if let week = calendar.dateInterval(of: .weekOfYear, for: trade.tradingDay)?.start {
                weekR[week, default: 0] += trade.actualR
                weekCounts[week, default: 0] += 1
                if trade.actualR > 0.05 { weekWins[week, default: 0] += 1 }
            }
            if let month = calendar.date(from: calendar.dateComponents([.year, .month], from: trade.tradingDay)) {
                monthR[month, default: 0] += trade.actualR
            }
        }
        let weeks = weekR.keys.sorted()

        func isPositive(_ r: Double?) -> Bool { (r ?? 0) > 0.05 }

        // MARK: Streaks

        var currentDayRun = 0
        for day in days.reversed() {
            if isPositive(dayMap[day]?.r) { currentDayRun += 1 } else { break }
        }
        var bestDayRun = 0
        var bestDayRunEnd: Date?
        var dayRun = 0
        for day in days {
            if isPositive(dayMap[day]?.r) {
                dayRun += 1
                if dayRun > bestDayRun {
                    bestDayRun = dayRun
                    bestDayRunEnd = day
                }
            } else {
                dayRun = 0
            }
        }

        var currentWeekRun = 0
        for week in weeks.reversed() {
            if isPositive(weekR[week]) { currentWeekRun += 1 } else { break }
        }
        var bestWeekRun = 0
        var bestWeekRunEnd: Date?
        var weekRun = 0
        var previous: Date?
        for week in weeks {
            if isPositive(weekR[week]) {
                if let previous,
                   let next = calendar.date(byAdding: .day, value: 7, to: previous),
                   next == week {
                    weekRun += 1
                } else {
                    weekRun = 1
                }
                if weekRun > bestWeekRun {
                    bestWeekRun = weekRun
                    bestWeekRunEnd = week
                }
            } else {
                weekRun = 0
            }
            previous = week
        }

        // MARK: Records

        let bestDay = dayMap.max { $0.value.r < $1.value.r }
        let bestWeek = weekR.max { $0.value < $1.value }
        let bestMonth = monthR.max { $0.value < $1.value }

        let bestWeekWinRate: (week: Date, rate: Double)? = weekR.compactMap { week, _ in
            guard let count = weekCounts[week], count > 0 else { return nil }
            return (week, Double(weekWins[week] ?? 0) / Double(count))
        }.max { $0.rate < $1.rate }

        // MARK: Goals

        let finishedGoals = goals.filter { goal in
            guard goal.targetR > 0,
                  let key = calendar.date(from: calendar.dateComponents([.year, .month], from: goal.monthStart)) else {
                return false
            }
            return (monthR[key] ?? 0) >= goal.targetR
        }
        let lastGoalMonth = finishedGoals.map(\.monthStart).max()

        // MARK: Days without SL

        let noSLDays = days.filter { !(dayMap[$0]?.hasSL ?? false) }.count
        let noSLRate = days.isEmpty ? 0 : Double(noSLDays) / Double(days.count)

        let hasTrades = !closed.isEmpty

        var items: [AchievementItem] = []

        items.append(
            AchievementItem(
                id: "weeks",
                title: "Серия недель",
                icon: "flame.fill",
                value: "\(currentWeekRun) \(weekWord(currentWeekRun))",
                caption: bestWeekRun > 0
                    ? "лучшая \(bestWeekRun)\(bestWeekRunEnd.map { " · \(monthName($0))" } ?? "")"
                    : "Пока не достигнуто",
                progress: bestWeekRun > 0 ? Double(currentWeekRun) / Double(bestWeekRun) : nil,
                isAchieved: hasTrades && bestWeekRun > 0
            )
        )

        items.append(
            AchievementItem(
                id: "days",
                title: "Серия дней",
                icon: "calendar",
                value: "\(currentDayRun) \(dayWord(currentDayRun)) с прибылью",
                caption: bestDayRun > 0
                    ? "рекорд \(bestDayRun)\(bestDayRunEnd.map { " · \(monthName($0))" } ?? "")"
                    : "Пока не достигнуто",
                progress: bestDayRun > 0 ? Double(currentDayRun) / Double(bestDayRun) : nil,
                isAchieved: hasTrades && bestDayRun > 0
            )
        )

        items.append(
            AchievementItem(
                id: "bestDay",
                title: "Лучший день",
                icon: "chart.bar.fill",
                value: bestDay.map { Fmt.r($0.value.r) } ?? "—",
                caption: bestDay.map { Fmt.shortDay($0.key).lowercased() } ?? "Пока не достигнуто",
                progress: nil,
                isAchieved: bestDay != nil
            )
        )

        items.append(
            AchievementItem(
                id: "bestWeek",
                title: "Лучшая неделя",
                icon: "chart.bar.fill",
                value: bestWeek.map { Fmt.r($0.value) } ?? "—",
                caption: bestWeek.map { weekRange($0.key, calendar: calendar) } ?? "Пока не достигнуто",
                progress: nil,
                isAchieved: bestWeek != nil
            )
        )

        items.append(
            AchievementItem(
                id: "bestMonth",
                title: "Лучший месяц",
                icon: "calendar",
                value: bestMonth.map { Fmt.r($0.value) } ?? "—",
                caption: bestMonth.map { monthYear($0.key) } ?? "Пока не достигнуто",
                progress: nil,
                isAchieved: bestMonth != nil
            )
        )

        items.append(
            AchievementItem(
                id: "goals",
                title: "Цели месяца",
                icon: "target",
                value: "\(finishedGoals.count) из \(goals.count)",
                caption: lastGoalMonth.map { "последняя — \(monthName($0))" } ?? "Пока не достигнуто",
                progress: goals.isEmpty ? 0 : Double(finishedGoals.count) / Double(goals.count),
                isAchieved: !finishedGoals.isEmpty
            )
        )

        items.append(
            AchievementItem(
                id: "noSL",
                title: "Без SL",
                icon: "shield.fill",
                value: "\(Int((noSLRate * 100).rounded()))% дней",
                caption: days.isEmpty ? "Пока не достигнуто" : "дни без стоп-лосса",
                progress: days.isEmpty ? nil : noSLRate,
                isAchieved: hasTrades
            )
        )

        items.append(
            AchievementItem(
                id: "winRateWeek",
                title: "Win rate недели",
                icon: "trophy.fill",
                value: bestWeekWinRate.map { "\(Int(($0.rate * 100).rounded()))%" } ?? "—",
                caption: bestWeekWinRate.map { "неделя \(weekRange($0.week, calendar: calendar))" } ?? "Пока не достигнуто",
                progress: nil,
                isAchieved: bestWeekWinRate != nil
            )
        )

        return items
    }

    // MARK: - Words and dates

    private static func weekWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "недель подряд" }
        if mod10 == 1 { return "неделя подряд" }
        if mod10 >= 2 && mod10 <= 4 { return "недели подряд" }
        return "недель подряд"
    }

    private static func dayWord(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        if mod10 == 1 { return "день" }
        if mod10 >= 2 && mod10 <= 4 { return "дня" }
        return "дней"
    }

    private static func weekRange(_ start: Date, calendar: Calendar) -> String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else { return "" }
        return "\(Fmt.dayMonth(start))–\(Fmt.dayMonth(end))"
    }

    private static func monthName(_ date: Date) -> String {
        Fmt.month(date).lowercased()
    }

    private static func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).lowercased()
    }
}

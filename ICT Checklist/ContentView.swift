//
//  ContentView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "checklist") }
            TradesView()
                .tabItem { Label("Сделки", systemImage: "list.bullet.rectangle") }
            RiskLadderView()
                .tabItem { Label("Ladder", systemImage: "stairs") }
            StatisticsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }
            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
        }
        .tint(Theme.blue)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                TradingCycle.self,
                KeyLevel.self,
                ScenarioRecord.self,
                Trade.self,
                TradeShot.self,
                RiskLadderState.self,
                AppSettings.self,
                MonthlyGoal.self
            ],
            inMemory: true
        )
}

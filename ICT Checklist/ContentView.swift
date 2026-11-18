//
//  ContentView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    @ObservedObject private var router = NotificationRouter.shared

    @State private var selection = 0
    @State private var revealTick = 0
    @State private var showGoal = false
    @State private var showWeekPlan = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "checklist") }
                .tag(0)
            TradesView()
                .tabItem { Label("Сделки", systemImage: "list.bullet.rectangle") }
                .tag(1)
            StatisticsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }
                .tag(2)
            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
                .tag(3)
            MoreView()
                .tabItem { Label("Ещё", systemImage: "square.grid.2x2") }
                .tag(4)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .environment(\.revealTick, revealTick)
        .onChange(of: selection) { _, _ in
            revealTick += 1
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, revealTick > 0 else { return }
            revealTick += 1
        }
        .onChange(of: router.goalRequestTick) { _, _ in
            if router.consumeGoalRequest() {
                showGoal = true
            }
        }
        .onChange(of: router.todayRequestTick) { _, _ in
            if router.consumeTodayRequest() {
                selection = 0
            }
        }
        .onChange(of: router.weekRequestTick) { _, _ in
            if router.consumeWeekRequest() {
                selection = 0
                showWeekPlan = true
            }
        }
        .onAppear {
            if router.consumeGoalRequest() {
                showGoal = true
            }
            if router.consumeTodayRequest() {
                selection = 0
            }
            if router.consumeWeekRequest() {
                selection = 0
                showWeekPlan = true
            }
        }
        .fullScreenCover(isPresented: $showGoal) {
            GoalView()
        }
        .fullScreenCover(isPresented: $showWeekPlan) {
            WeekPlanView()
        }
        .task {
            NotificationRouter.shared.install()
            GoalReminder.check(context: context)
            JournalReminder.refresh(context: context)
            DailyLimitReminder.check(context: context)
            WeekPlanReminder.refresh(context: context)
        }
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
                MonthlyGoal.self,
                TradePlan.self,
                PlanPhoto.self,
                TradingAccount.self,
                AccountOperation.self,
                LossReview.self,
                TradeReview.self,
                ErrorNote.self,
                ErrorShot.self,
                BrainNote.self,
                BrainShot.self,
                JournalEntry.self,
                WeekPlan.self,
                WeekScenario.self,
                SystemBlueprint.self,
                TraderProfile.self,
                AssistantMessage.self
            ],
            inMemory: true
        )
}

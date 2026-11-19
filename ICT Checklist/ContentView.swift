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

    @Query private var existingTrades: [Trade]
    @Query private var existingPlans: [TradePlan]
    @Query private var settingsList: [AppSettings]

    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    @State private var selection = 0
    @State private var revealTick = 0
    @State private var showLaunch = true
    @State private var showGoal = false
    @State private var showWeekPlan = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabEntrance()
                .tabItem { Label("Сегодня", systemImage: "checklist") }
                .tag(0)
            TradesView()
                .tabEntrance()
                .tabItem { Label("Сделки", systemImage: "list.bullet.rectangle") }
                .tag(1)
            StatisticsView()
                .tabEntrance()
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }
                .tag(2)
            MoreView()
                .tabEntrance()
                .tabItem { Label("Ещё", systemImage: "square.grid.2x2") }
                .tag(3)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .overlay {
            if showLaunch {
                LaunchMark()
                    .transition(.opacity)
                    .zIndex(60)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                showLaunch = false
            }
        }
        .environment(\.revealTick, revealTick)
        .onChange(of: selection) { _, _ in
            revealTick += 1
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            CycleActivityController.shared.sync(context: context)
            guard revealTick > 0 else { return }
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onChange(of: onboardingCompleted) { _, done in
            if done {
                showOnboarding = false
            }
        }
        .task {
            if !onboardingCompleted {
                if existingTrades.isEmpty && existingPlans.isEmpty {
                    showOnboarding = true
                } else {
                    // В базе уже есть записи — значит это не первый запуск.
                    onboardingCompleted = true
                }
            }
            NotificationRouter.shared.install()
            GoalReminder.check(context: context)
            JournalReminder.refresh(context: context)
            DailyLimitReminder.check(context: context)
            WeekPlanReminder.refresh(context: context)
            TradeReviewReminder.refresh(context: context)
            CycleActivityController.shared.sync(context: context)
            PlaybookEngine.seedIfNeeded(context: context, settings: settingsList.first)
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
                TrainingRun.self,
                AssistantMessage.self,
                PlaybookSetup.self
            ],
            inMemory: true
        )
}

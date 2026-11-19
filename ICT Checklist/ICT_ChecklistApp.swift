//
//  ICT_ChecklistApp.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

@main
struct ICT_ChecklistApp: App {
    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ContentView()
            }
        }
        .modelContainer(AppContainer.shared)
    }
}

/// The app's single store. Everything stays on this device; there is no cloud sync.
enum AppContainer {
    static let schema = Schema([
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
        PlaybookSetup.self,
        BankRateRevision.self,
        AdviceHypothesis.self,
        FundMandate.self,
        CommitteeProtocol.self,
        SystemVersion.self
    ])

    static let shared: ModelContainer = {
        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Не удалось создать локальное хранилище: \(error)")
        }
    }()
}

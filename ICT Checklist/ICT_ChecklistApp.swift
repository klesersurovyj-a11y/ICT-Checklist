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
            ContentView()
        }
        .modelContainer(AppContainer.shared)
    }
}

/// The app's single store. It is mirrored to iCloud when that is available,
/// and always stays usable from the local database when it is not.
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
    ])

    static let shared: ModelContainer = {
        if CloudAvailability.hasICloudEntitlement {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )

            if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
                return container
            }
        }

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

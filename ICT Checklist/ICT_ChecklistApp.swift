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
        .modelContainer(for: [
            TradingCycle.self,
            KeyLevel.self,
            ScenarioRecord.self,
            Trade.self,
            TradeShot.self,
            RiskLadderState.self,
            AppSettings.self
        ])
    }
}

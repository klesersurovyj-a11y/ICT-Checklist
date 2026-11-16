//
//  SyncStatus.swift
//  ICT Checklist
//

import Foundation
import Combine
import CloudKit
import CoreData
import SwiftUI

/// Tracks whether iCloud sync is available and when the last sync ran.
/// The local SwiftData store stays the primary one: when CloudKit is
/// unavailable the app keeps working exactly as before.
final class SyncStatus: ObservableObject {
    static let shared = SyncStatus()

    static let containerIdentifier = "iCloud.com.organizationName.ICT-Checklist"

    private enum Keys {
        static let lastSyncDate = "iCloud.lastSyncDate"
        static let lastSyncFailed = "iCloud.lastSyncFailed"
    }

    enum Account: String {
        case unknown
        case active
        case noAccount
        case restricted
        case unavailable

        var title: String {
            switch self {
            case .unknown: return "Проверка…"
            case .active: return "Включена"
            case .noAccount: return "Нет аккаунта iCloud"
            case .restricted: return "Ограничена"
            case .unavailable: return "Недоступна"
            }
        }

        var detail: String {
            switch self {
            case .unknown:
                return "Проверяем доступность iCloud"
            case .active:
                return "Изменения уходят и приходят сами"
            case .noAccount:
                return "Войдите в iCloud в настройках iOS, чтобы данные переносились между устройствами"
            case .restricted:
                return "Синхронизация ограничена настройками этого устройства"
            case .unavailable:
                return "Нет связи с iCloud. Приложение работает с локальной базой"
            }
        }

        var tint: Color {
            switch self {
            case .unknown: return Theme.textSecondary
            case .active: return Theme.green
            case .noAccount, .restricted: return Theme.orange
            case .unavailable: return Theme.red
            }
        }
    }

    @Published private(set) var account: Account = .unknown
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncFailed: Bool = false

    private var isChecking = false

    private init() {
        let defaults = UserDefaults.standard
        lastSyncDate = defaults.object(forKey: Keys.lastSyncDate) as? Date
        lastSyncFailed = defaults.bool(forKey: Keys.lastSyncFailed)
    }

    /// Re-reads the account state. Safe to call on every appearance.
    func start() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let container = CKContainer(identifier: Self.containerIdentifier)
            let status = try await container.accountStatus()
            let resolved = Self.account(for: status)
            DispatchQueue.main.async {
                self.account = resolved
            }
        } catch {
            DispatchQueue.main.async {
                self.account = .unavailable
            }
        }
    }

    /// Feeds `NSPersistentCloudKitContainer.eventChangedNotification` events.
    func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }
        guard event.type == .import || event.type == .export else { return }
        guard let endDate = event.endDate else { return }

        let failed = !event.succeeded

        DispatchQueue.main.async {
            self.lastSyncDate = endDate
            self.lastSyncFailed = failed
        }

        let defaults = UserDefaults.standard
        defaults.set(endDate, forKey: Keys.lastSyncDate)
        defaults.set(failed, forKey: Keys.lastSyncFailed)
    }

    private static func account(for status: CKAccountStatus) -> Account {
        switch status {
        case .available: return .active
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine, .temporarilyUnavailable: return .unavailable
        @unknown default: return .unavailable
        }
    }
}

//
//  SyncStatus.swift
//  ICT Checklist
//

import Foundation
import Combine
import CoreData
import SwiftUI

/// Tracks whether iCloud sync is available and when the last sync ran.
/// The local SwiftData store stays the primary one: when CloudKit is
/// unavailable the app keeps working exactly as before.
final class SyncStatus: ObservableObject {
    static let shared = SyncStatus()

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
        case localOnly

        var title: String {
            switch self {
            case .unknown: return "Ожидает"
            case .active: return "Включена"
            case .noAccount: return "Нет аккаунта iCloud"
            case .restricted: return "Ограничена"
            case .unavailable: return "Недоступна"
            case .localOnly: return "Только на устройстве"
            }
        }

        var detail: String {
            switch self {
            case .unknown:
                return "Синхронизация запустится при изменениях"
            case .active:
                return "Изменения уходят и приходят сами"
            case .noAccount:
                return "Войдите в iCloud в настройках iOS, чтобы данные переносились между устройствами"
            case .restricted:
                return "Синхронизация ограничена настройками этого устройства"
            case .unavailable:
                return "Нет связи с iCloud. Приложение работает с локальной базой"
            case .localOnly:
                return "В этой сборке нет доступа к iCloud — данные хранятся локально"
            }
        }

        var tint: Color {
            switch self {
            case .unknown: return Theme.textSecondary
            case .active: return Theme.green
            case .noAccount, .restricted: return Theme.orange
            case .unavailable: return Theme.red
            case .localOnly: return Theme.textSecondary
            }
        }
    }

    @Published private(set) var account: Account = .unknown
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncFailed: Bool = false

    private init() {
        let defaults = UserDefaults.standard
        lastSyncDate = defaults.object(forKey: Keys.lastSyncDate) as? Date
        lastSyncFailed = defaults.bool(forKey: Keys.lastSyncFailed)
    }

    func start() {
        refresh()
    }

    /// Never touches `CKContainer` or other iCloud APIs: on a re-signed build
    /// without the entitlement they throw an Objective-C exception and
    /// terminate the app, which is why Settings must stay clear of them.
    func refresh() {
        guard CloudAvailability.hasICloudEntitlement else {
            account = .localOnly
            return
        }

        if lastSyncFailed {
            account = .unavailable
            return
        }

        account = lastSyncDate == nil ? .unknown : .active
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
            self.refresh()
        }

        let defaults = UserDefaults.standard
        defaults.set(endDate, forKey: Keys.lastSyncDate)
        defaults.set(failed, forKey: Keys.lastSyncFailed)
    }
}

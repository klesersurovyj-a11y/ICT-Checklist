//
//  CloudAvailability.swift
//  ICT Checklist
//

import Foundation

enum CloudAvailability {
    /// Есть ли в подписи приложения entitlement CloudKit.
    ///
    /// Создание `CKContainer` без этого entitlement падает необработанным
    /// исключением Objective-C, а не Swift-ошибкой, поэтому такие сборки
    /// (например переподписанные сторонним инструментом) должны работать
    /// только с локальной базой и вообще не трогать CloudKit.
    static let hasICloudEntitlement: Bool = {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let data = try? Data(contentsOf: url)
        else {
            return false
        }

        let text = String(decoding: data, as: UTF8.self)
        return text.contains("com.apple.developer.icloud-services")
            && text.contains("CloudKit")
    }()
}

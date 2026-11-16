//
//  ScreenshotStore.swift
//  ICT Checklist
//

import Foundation

enum ScreenshotStore {
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(for fileName: String) -> URL {
        directory().appendingPathComponent(fileName)
    }

    static func save(data: Data) throws -> String {
        let name = UUID().uuidString + ".img"
        try data.write(to: url(for: name), options: .atomic)
        return name
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}

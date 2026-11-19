//
//  ScreenshotStore.swift
//  ICT Checklist
//

import Foundation
import UIKit

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
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// New screenshots live in SwiftData on this device;
    /// screenshots taken before that change are still files on disk.
    static func image(for shot: TradeShot) -> UIImage? {
        if let data = shot.imageData, let image = UIImage(data: data) {
            return image
        }
        guard !shot.fileName.isEmpty else { return nil }
        return UIImage(contentsOfFile: url(for: shot.fileName).path(percentEncoded: false))
    }
}

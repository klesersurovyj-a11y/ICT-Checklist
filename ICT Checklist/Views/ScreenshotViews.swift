//
//  ScreenshotViews.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData
import UIKit

struct ShotThumbnail: View {
    let fileName: String
    var size: CGFloat = 56

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: fileName) {
            guard image == nil else { return }
            image = UIImage(contentsOfFile: ScreenshotStore.url(for: fileName).path(percentEncoded: false))
        }
    }
}

struct ShotImage: View {
    let fileName: String
    var maxHeight: CGFloat = 420

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.textTertiary)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: fileName) {
            guard image == nil else { return }
            image = UIImage(contentsOfFile: ScreenshotStore.url(for: fileName).path(percentEncoded: false))
        }
    }
}

struct ScreenshotsGallery: View {
    let trade: Trade

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Скриншоты")
                        Text("\(trade.symbol) · \(Fmt.shortDay(trade.tradingDay))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer(minLength: 8)
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if trade.sortedShots.isEmpty {
                            Text("Скриншотов пока нет")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                        } else {
                            ForEach(trade.sortedShots) { shot in
                                VStack(spacing: 8) {
                                    ShotImage(fileName: shot.fileName)
                                    Button {
                                        delete(shot)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash")
                                            Text("Удалить")
                                        }
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Theme.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Theme.red.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func delete(_ shot: TradeShot) {
        ScreenshotStore.delete(shot.fileName)
        trade.shots.removeAll { $0 === shot }
        context.delete(shot)
        try? context.save()
        Haptics.tap()
    }
}

//
//  ShareSheet.swift
//  ICT Checklist
//

import SwiftUI
import UIKit

/// Системное меню «Поделиться» для PDF, CSV и резервной копии.
///
/// `UIActivityViewController` нельзя встраивать в SwiftUI `.sheet`: он
/// рассчитан на модальную презентацию, а внутри листа открывается пустым
/// или сразу закрывается. Поэтому показываем его напрямую поверх
/// текущего экрана.
enum SharePresenter {
    static func share(_ items: [Any]) {
        guard !items.isEmpty else { return }
        guard let host = topViewController() else { return }

        let activity = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        if let popover = activity.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(
                x: host.view.bounds.midX,
                y: host.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        host.present(activity, animated: true)
    }

    /// Видимое сообщение, если файл не удалось собрать:
    /// иначе кнопка экспорта просто «ничего не делает».
    static func presentFailure(_ message: String = "Файл не создался. Попробуйте ещё раз.") {
        guard let host = topViewController() else { return }
        let alert = UIAlertController(
            title: "Не удалось экспортировать",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        host.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        guard var controller = window?.rootViewController else { return nil }

        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

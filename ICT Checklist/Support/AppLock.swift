//
//  AppLock.swift
//  ICT Checklist
//
//  Замок приложения: Face ID, Touch ID или код-пароль устройства
//  при запуске и возврате из фона. Данные при этом остаются
//  на этом устройстве — замок защищает только доступ к приложению.
//

import SwiftUI
import LocalAuthentication
import UIKit

@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    @Published private(set) var isLocked = false
    @Published private(set) var isEnabled = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var errorText: String?
    /// Меняется при возврате из фона — по нему экран замка просит Face ID снова.
    @Published private(set) var promptTick = 0

    private static let enabledKey = "appLock.enabled"
    private var started = false

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        isEnabled = value

        guard !value else { return }
        isLocked = false
        errorText = nil
        LockWindowController.shared.hide()
    }

    func start() {
        guard !started else { return }
        started = true
        lock()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lock()
        case .active:
            guard isEnabled, isLocked else { return }
            LockWindowController.shared.show()
            promptTick += 1
        default:
            break
        }
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
        errorText = nil
        LockWindowController.shared.show()
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }

        let context = LAContext()
        var failure: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            errorText = "На устройстве не настроены Face ID, Touch ID или код-пароль."
            return
        }

        isAuthenticating = true
        errorText = nil
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Открыть ICT Checklist"
            )
            if success {
                isLocked = false
                LockWindowController.shared.hide()
                Haptics.success()
            }
        } catch {
            errorText = "Подтвердить личность не удалось. Попробуйте снова."
            Haptics.warning()
        }
    }
}

/// Отдельное окно поверх всего приложения, включая открытые экраны и листы.
@MainActor
final class LockWindowController {
    static let shared = LockWindowController()

    private var window: UIWindow?

    private init() {}

    func show() {
        guard window == nil else { return }
        guard let scene = activeScene() else { return }

        let host = UIHostingController(rootView: AppLockView())
        host.view.backgroundColor = .black

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.isHidden = false

        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }

    private func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

struct AppLockView: View {
    @ObservedObject private var lock = AppLock.shared

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 88, height: 88)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 4)

                Text("Приложение заблокировано")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Разблокируйте через Face ID, Touch ID или код-пароль устройства.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if lock.isAuthenticating {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 2)
                }

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Text("Разблокировать")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 6)

                if let errorText = lock.errorText {
                    Text(errorText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Сделки, планы и заметки остаются на этом устройстве.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(28)
        }
        .task {
            guard UIApplication.shared.applicationState == .active else { return }
            await lock.unlock()
        }
        .onChange(of: lock.promptTick) { _, _ in
            Task { await lock.unlock() }
        }
    }
}

/// Запускает замок и следит за уходом приложения в фон.
struct AppLockGate<Content: View>: View {
    @ObservedObject private var lock = AppLock.shared
    @Environment(\.scenePhase) private var scenePhase

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onAppear { lock.start() }
            .onChange(of: scenePhase) { _, phase in
                lock.handleScenePhase(phase)
            }
    }
}

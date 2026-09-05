import Foundation
import UserNotifications

/// macOS 原生通知封装（横幅 + 通知中心）。授权被拒时静默，预警历史仍会记录。
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private var authorizationRequested = false

    /// 仅在用户首次创建预警时调用，避免应用启动就弹权限框。
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        guard !authorizationRequested else {
            return await currentAuthorizationStatus().allowsNotify
        }
        authorizationRequested = true
        let granted: Bool = await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
        return granted
    }

    /// 发送一条预警通知；授权未授予则静默跳过（不抛错）。
    func send(_ record: AlertTriggerRecord) {
        Task { [weak self] in
            guard await self?.currentAuthorizationStatus().allowsNotify == true else { return }
            let content = UNMutableNotificationContent()
            content.title = record.title
            content.body = "当前 \(Format.price(record.triggeredPrice))"
            if let note = record.note, !note.isEmpty {
                content.body += "　·　\(note)"
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: record.id.uuidString,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func currentAuthorizationStatus() async -> AuthorizationInfo {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let ok: Bool = {
                    switch settings.authorizationStatus {
                    case .authorized, .provisional, .ephemeral: return true
                    default: return false
                    }
                }()
                cont.resume(returning: AuthorizationInfo(allowsNotify: ok))
            }
        }
    }

    private struct AuthorizationInfo {
        let allowsNotify: Bool
    }
}

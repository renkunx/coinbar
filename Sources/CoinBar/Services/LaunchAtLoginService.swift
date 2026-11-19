import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var requiresApproval: Bool = false
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    /// `swift run` 直接执行可执行文件时没有 .app 包，SMAppService 无法注册
    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}

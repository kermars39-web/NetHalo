import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var launchAtLogin = false
    @Published var launchError: String?

    init() {
        refreshLaunchAtLogin()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchError = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchError = "暂时无法修改开机启动：\(error.localizedDescription)"
        }

        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

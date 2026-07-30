import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let showNetwork = "menu.showNetwork"
        static let showCPU = "menu.showCPU"
        static let showMemory = "menu.showMemory"
    }

    private let defaults: UserDefaults

    @Published var showNetwork: Bool {
        didSet { defaults.set(showNetwork, forKey: Key.showNetwork) }
    }

    @Published var showCPU: Bool {
        didSet { defaults.set(showCPU, forKey: Key.showCPU) }
    }

    @Published var showMemory: Bool {
        didSet { defaults.set(showMemory, forKey: Key.showMemory) }
    }

    @Published private(set) var launchAtLogin = false
    @Published var launchError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showNetwork = defaults.object(forKey: Key.showNetwork) as? Bool ?? true
        showCPU = defaults.object(forKey: Key.showCPU) as? Bool ?? true
        showMemory = defaults.object(forKey: Key.showMemory) as? Bool ?? true
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

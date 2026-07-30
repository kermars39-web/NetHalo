import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private static let selectedDetailMetricKey = "selectedDetailMetric"

    @Published private(set) var launchAtLogin = false
    @Published private(set) var selectedDetailMetric: DetailMetric
    @Published var launchError: String?

    init() {
        selectedDetailMetric = DetailMetric(
            rawValue: UserDefaults.standard.string(forKey: Self.selectedDetailMetricKey) ?? ""
        ) ?? .network
        refreshLaunchAtLogin()
    }

    func selectDetailMetric(_ metric: DetailMetric) {
        guard selectedDetailMetric != metric else { return }
        selectedDetailMetric = metric
        UserDefaults.standard.set(metric.rawValue, forKey: Self.selectedDetailMetricKey)
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

import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private static let selectedDetailMetricKey = "selectedDetailMetric"
    private static let launchRegistrationFingerprintKey = "launchRegistrationFingerprint"

    @Published private(set) var launchAtLogin = false
    @Published private(set) var selectedDetailMetric: DetailMetric
    @Published var launchError: String?

    init() {
        selectedDetailMetric = DetailMetric(
            rawValue: UserDefaults.standard.string(forKey: Self.selectedDetailMetricKey) ?? ""
        ) ?? .network
        refreshLaunchAtLogin()
        refreshLaunchRegistrationAfterUpdateIfNeeded()
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
                rememberCurrentLaunchRegistration()
            } else {
                try SMAppService.mainApp.unregister()
                UserDefaults.standard.removeObject(forKey: Self.launchRegistrationFingerprintKey)
            }
        } catch {
            launchError = "暂时无法修改开机启动：\(error.localizedDescription)"
        }

        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Re-register after the app bundle changes so System Settings refreshes
    /// the login item's path, version, and icon metadata instead of retaining a
    /// stale placeholder from an older local build.
    private func refreshLaunchRegistrationAfterUpdateIfNeeded() {
        guard launchAtLogin else { return }

        let currentFingerprint = launchRegistrationFingerprint
        guard UserDefaults.standard.string(forKey: Self.launchRegistrationFingerprintKey) != currentFingerprint else {
            return
        }

        do {
            try SMAppService.mainApp.unregister()
            try SMAppService.mainApp.register()
            rememberCurrentLaunchRegistration()
        } catch {
            launchError = "开机启动登记需要刷新：\(error.localizedDescription)"
        }

        refreshLaunchAtLogin()
    }

    private var launchRegistrationFingerprint: String {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(bundlePath)|\(build)"
    }

    private func rememberCurrentLaunchRegistration() {
        UserDefaults.standard.set(
            launchRegistrationFingerprint,
            forKey: Self.launchRegistrationFingerprintKey
        )
    }
}

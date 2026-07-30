import Combine
import Foundation

final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = MetricsSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var topNetworkApps: [NetworkAppMetric] = []
    @Published private(set) var topCPUApps: [ProcessAppMetric] = []
    @Published private(set) var topMemoryApps: [ProcessAppMetric] = []
    @Published private(set) var networkAppsReady = false
    @Published private(set) var resourceAppsReady = false

    private let sampler = MetricsSampler()
    private var timer: Timer?
    private var samplesSinceAppRefresh = 0
    private var detailsVisible = false
    private var appRefreshInFlight = false

    func start() {
        guard timer == nil else { return }

        _ = sampler.sample() // Seed the delta-based CPU and network counters.
        sampleNow()
        scheduleTimer(interval: 2)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setDetailsVisible(_ visible: Bool) {
        guard detailsVisible != visible else { return }
        detailsVisible = visible
        scheduleTimer(interval: visible ? 1 : 2)
        if visible {
            sampleNow()
            refreshAppMetrics()
        }
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleNow()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func sampleNow() {
        let value = sampler.sample()
        snapshot = value

        cpuHistory.appendKeepingLast(value.cpuPercent, limit: 60)
        memoryHistory.appendKeepingLast(value.memoryPercent, limit: 60)
        downloadHistory.appendKeepingLast(value.downloadBytesPerSecond, limit: 60)
        uploadHistory.appendKeepingLast(value.uploadBytesPerSecond, limit: 60)

        samplesSinceAppRefresh += 1
        if detailsVisible, samplesSinceAppRefresh >= 5 {
            refreshAppMetrics()
        }
    }

    private func refreshAppMetrics() {
        guard !appRefreshInFlight else { return }
        appRefreshInFlight = true
        samplesSinceAppRefresh = 0

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let resources = ProcessResourceSampler.sampleTopApps()
            let network = ProcessNetworkSampler.sampleTopApps()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.networkAppsReady = true
                self.resourceAppsReady = true
                self.topNetworkApps = network
                self.topCPUApps = resources.topCPUApps
                self.topMemoryApps = resources.topMemoryApps
                self.appRefreshInFlight = false
            }
        }
    }
}

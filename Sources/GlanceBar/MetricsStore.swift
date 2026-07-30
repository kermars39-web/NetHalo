import Combine
import Foundation

final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = MetricsSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var topProcesses: [ProcessMetric] = []

    private let sampler = MetricsSampler()
    private var timer: Timer?
    private var samplesSinceProcessRefresh = 0
    private var detailsVisible = false
    private var processRefreshInFlight = false

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
            refreshProcesses()
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

        samplesSinceProcessRefresh += 1
        if detailsVisible, samplesSinceProcessRefresh >= 5 {
            refreshProcesses()
        }
    }

    private func refreshProcesses() {
        guard !processRefreshInFlight else { return }
        processRefreshInFlight = true
        samplesSinceProcessRefresh = 0

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let values = MetricsSampler.sampleTopProcesses()
            DispatchQueue.main.async { [weak self] in
                self?.topProcesses = values
                self?.processRefreshInFlight = false
            }
        }
    }
}

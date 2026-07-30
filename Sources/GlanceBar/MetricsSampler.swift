import Darwin
import Foundation

final class MetricsSampler {
    private struct CPUTicks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64

        var total: UInt64 { user + system + idle + nice }
        var used: UInt64 { user + system + nice }
    }

    private struct NetworkTotals {
        let received: UInt64
        let sent: UInt64
    }

    private var previousCPU: CPUTicks?
    private var previousNetwork: NetworkTotals?
    private var previousNetworkTime: TimeInterval?

    func sample() -> MetricsSnapshot {
        let now = ProcessInfo.processInfo.systemUptime
        let cpu = sampleCPU()
        let memory = sampleMemory()
        let network = sampleNetwork(at: now)

        return MetricsSnapshot(
            cpuPercent: cpu,
            memoryPercent: memory.percent,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            downloadBytesPerSecond: network.download,
            uploadBytesPerSecond: network.upload,
            sampledAt: Date()
        )
    }

    private func sampleCPU() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let current = CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )

        defer { previousCPU = current }
        guard let previousCPU else { return 0 }

        let totalDelta = counterDelta(current.total, previousCPU.total)
        let usedDelta = counterDelta(current.used, previousCPU.used)
        guard totalDelta > 0 else { return 0 }

        return min(100, max(0, Double(usedDelta) / Double(totalDelta) * 100))
    }

    private func sampleMemory() -> (used: UInt64, total: UInt64, percent: Double) {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS, total > 0 else { return (0, total, 0) }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        // Active + wired + compressed is a useful approximation of memory that
        // is genuinely under pressure. Inactive cache is intentionally excluded.
        let usedPages = UInt64(statistics.active_count)
            + UInt64(statistics.wire_count)
            + UInt64(statistics.compressor_page_count)
        let used = min(total, usedPages * UInt64(pageSize))
        let percent = Double(used) / Double(total) * 100

        return (used, total, percent)
    }

    private func sampleNetwork(at now: TimeInterval) -> (download: Double, upload: Double) {
        let current = readNetworkTotals()
        defer {
            previousNetwork = current
            previousNetworkTime = now
        }

        guard let previousNetwork, let previousNetworkTime else { return (0, 0) }
        let elapsed = max(0.1, now - previousNetworkTime)
        let received = counterDelta(current.received, previousNetwork.received)
        let sent = counterDelta(current.sent, previousNetwork.sent)

        return (Double(received) / elapsed, Double(sent) / elapsed)
    }

    private func readNetworkTotals() -> NetworkTotals {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let firstAddress = addressList else {
            return NetworkTotals(received: 0, sent: 0)
        }
        defer { freeifaddrs(addressList) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer {
            let interface = current.pointee
            defer { pointer = interface.ifa_next }

            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let flags = interface.ifa_flags
            guard flags & UInt32(IFF_UP) != 0,
                  flags & UInt32(IFF_LOOPBACK) == 0 else { continue }

            let name = String(cString: interface.ifa_name)
            // Physical Wi-Fi and Ethernet adapters are named en0, en1, en5…
            // Excluding awdl/llw/utun avoids double-counting peer and VPN traffic.
            guard name.hasPrefix("en"), let dataPointer = interface.ifa_data else { continue }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(data.ifi_ibytes)
            sent += UInt64(data.ifi_obytes)
        }

        return NetworkTotals(received: received, sent: sent)
    }

    private func counterDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : current
    }

    static func sampleTopProcesses(limit: Int = 5) -> [ProcessMetric] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,comm=", "-r"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var results: [ProcessMetric] = []

        for line in output.split(separator: "\n") {
            let fields = line.split(
                separator: " ",
                maxSplits: 3,
                omittingEmptySubsequences: true
            )
            guard fields.count == 4,
                  let pid = Int32(fields[0]),
                  pid != ownPID,
                  let cpu = Double(fields[1]),
                  let residentKB = UInt64(fields[2]) else { continue }

            let command = String(fields[3])
            let lastComponent = (command as NSString).lastPathComponent
            let name = lastComponent.isEmpty ? command : lastComponent

            results.append(ProcessMetric(
                pid: pid,
                name: name,
                cpuPercent: cpu,
                memoryBytes: residentKB * 1_024
            ))

            if results.count >= limit { break }
        }

        return results
    }
}

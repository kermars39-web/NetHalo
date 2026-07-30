import Darwin
import Foundation

struct ProcessResourceSnapshot {
    let topCPUApps: [ProcessAppMetric]
    let topMemoryApps: [ProcessAppMetric]
}

enum ProcessResourceSampler {
    private struct Totals {
        var cpuPercent: Double = 0
        var memoryBytes: UInt64 = 0
        var iconPath: String?
    }

    static func sampleTopApps(limit: Int = 4) -> ProcessResourceSnapshot {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,comm="]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ProcessResourceSnapshot(topCPUApps: [], topMemoryApps: [])
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else {
            return ProcessResourceSnapshot(topCPUApps: [], topMemoryApps: [])
        }

        return parsePSOutput(text, limit: limit)
    }

    static func parsePSOutput(_ text: String, limit: Int = 4) -> ProcessResourceSnapshot {
        var totalsByApp: [String: Totals] = [:]

        for rawLine in text.split(separator: "\n") {
            let fields = rawLine.split(
                maxSplits: 3,
                omittingEmptySubsequences: true,
                whereSeparator: { $0.isWhitespace }
            )
            guard fields.count == 4,
                  let pid = pid_t(fields[0]),
                  pid != getpid(),
                  let cpuPercent = Double(fields[1]),
                  let residentKilobytes = UInt64(fields[2]),
                  let descriptor = ProcessAppResolver.descriptor(
                    rawName: String(fields[3]),
                    pid: pid,
                    includeSystemProcesses: true
                  ) else { continue }

            var totals = totalsByApp[descriptor.name, default: Totals()]
            totals.cpuPercent += max(0, cpuPercent)
            totals.memoryBytes += residentKilobytes * 1_024
            if let candidate = descriptor.iconPath,
               totals.iconPath == nil || !(totals.iconPath?.contains(".app") ?? false) {
                totals.iconPath = candidate
            }
            totalsByApp[descriptor.name] = totals
        }

        let apps = totalsByApp.map { name, totals in
            ProcessAppMetric(
                name: name,
                iconPath: totals.iconPath,
                cpuPercent: totals.cpuPercent,
                memoryBytes: totals.memoryBytes
            )
        }

        let cpu = apps.sorted { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
        .prefix(limit)
        .map { $0 }

        let memory = apps.sorted { lhs, rhs in
            if lhs.memoryBytes == rhs.memoryBytes {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.memoryBytes > rhs.memoryBytes
        }
        .prefix(limit)
        .map { $0 }

        return ProcessResourceSnapshot(topCPUApps: cpu, topMemoryApps: memory)
    }
}

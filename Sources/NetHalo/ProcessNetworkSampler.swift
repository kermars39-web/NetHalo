import Darwin
import Foundation

enum ProcessNetworkSampler {
    private struct Totals {
        var download: Double = 0
        var upload: Double = 0
        var iconPath: String?
    }

    static func sampleTopApps(limit: Int = 4) -> [NetworkAppMetric] {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = [
            "-P", "-L", "2", "-d", "-x", "-n",
            "-t", "external", "-s", "1",
            "-J", "bytes_in,bytes_out"
        ]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return [] }

        return parseDeltaCSV(text, limit: limit)
    }

    static func parseDeltaCSV(_ text: String, limit: Int = 4) -> [NetworkAppMetric] {
        let marker = ",bytes_in,bytes_out,"
        guard let lastMarker = text.range(of: marker, options: .backwards) else { return [] }

        let deltaBlock = text[lastMarker.upperBound...]
        var totalsByApp: [String: Totals] = [:]

        for rawLine in deltaBlock.split(separator: "\n") {
            let fields = rawLine.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3,
                  let identity = parseIdentity(String(fields[0])),
                  let descriptor = ProcessAppResolver.descriptor(
                    rawName: identity.name,
                    pid: identity.pid,
                    includeSystemProcesses: false
                  ),
                  let download = Double(fields[1]),
                  let upload = Double(fields[2]) else { continue }

            guard download + upload >= 512 else { continue }
            var totals = totalsByApp[descriptor.name, default: Totals()]
            totals.download += max(0, download)
            totals.upload += max(0, upload)
            if let candidate = descriptor.iconPath,
               totals.iconPath == nil || !(totals.iconPath?.contains(".app") ?? false) {
                totals.iconPath = candidate
            }
            totalsByApp[descriptor.name] = totals
        }

        return totalsByApp.map { name, totals in
            NetworkAppMetric(
                name: name,
                iconPath: totals.iconPath,
                downloadBytesPerSecond: totals.download,
                uploadBytesPerSecond: totals.upload
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalBytesPerSecond == rhs.totalBytesPerSecond {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.totalBytesPerSecond > rhs.totalBytesPerSecond
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func parseIdentity(_ value: String) -> (name: String, pid: pid_t)? {
        guard let separator = value.lastIndex(of: "."),
              let pid = pid_t(value[value.index(after: separator)...]) else { return nil }
        return (String(value[..<separator]), pid)
    }

}

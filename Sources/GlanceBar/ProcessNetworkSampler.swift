import AppKit
import Foundation

enum ProcessNetworkSampler {
    private struct Totals {
        var download: Double = 0
        var upload: Double = 0
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
                  let displayName = displayName(rawName: identity.name, pid: identity.pid),
                  let download = Double(fields[1]),
                  let upload = Double(fields[2]) else { continue }

            guard download + upload >= 512 else { continue }
            var totals = totalsByApp[displayName, default: Totals()]
            totals.download += max(0, download)
            totals.upload += max(0, upload)
            totalsByApp[displayName] = totals
        }

        return totalsByApp.map { name, totals in
            NetworkAppMetric(
                name: name,
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

    private static func displayName(rawName: String, pid: pid_t) -> String? {
        let runningApplication = NSRunningApplication(processIdentifier: pid)
        let resolved = runningApplication?.localizedName ?? rawName
        let bundleName = runningApplication?.bundleURL?
            .deletingPathExtension()
            .lastPathComponent
        let combined = "\(resolved) \(bundleName ?? "") \(rawName)".lowercased()

        let systemNames = [
            "launchd", "syslogd", "apsd", "usbmuxd", "dhcp6d", "airportd",
            "mdnsresponder", "wifip2pd", "rapportd", "controlcenter",
            "identityservice", "sharingd", "homed", "netbiosd", "nettop"
        ]
        if systemNames.contains(where: { combined.contains($0) }) { return nil }

        if combined.contains("google chrome") { return "Google Chrome" }
        if combined.contains("doubao browser") { return "豆包浏览器" }
        if combined.contains("feishu") || combined.contains("lark") { return "飞书" }
        if combined.contains("wechat") { return "微信" }
        if combined.contains("wpsoffice") || combined.contains("wps笔记") { return "WPS Office" }
        if combined.contains("onedrive") { return "OneDrive" }
        if combined.contains("chatgpt") { return "ChatGPT" }
        if combined.contains("codex") { return "Codex" }
        if combined.contains("termius") { return "Termius" }
        if combined.contains("rustdesk") { return "RustDesk" }
        if combined.contains("boostnet") || combined.contains("boostcore") { return "BoostNet" }
        if combined.contains("safari") { return "Safari" }
        if combined.contains("mail") { return "邮件" }

        var cleaned = bundleName ?? resolved
        if let helperRange = cleaned.range(of: " Helper", options: .caseInsensitive) {
            cleaned = String(cleaned[..<helperRange.lowerBound])
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.hasPrefix("com.apple.") else { return nil }
        return cleaned
    }
}

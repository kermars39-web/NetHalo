import AppKit
import Darwin
import Foundation

enum ProcessNetworkSampler {
    private struct Totals {
        var download: Double = 0
        var upload: Double = 0
        var iconPath: String?
    }

    private struct AppDescriptor {
        let name: String
        let iconPath: String?
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
                  let descriptor = appDescriptor(rawName: identity.name, pid: identity.pid),
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

    private static func appDescriptor(rawName: String, pid: pid_t) -> AppDescriptor? {
        let runningApplication = NSRunningApplication(processIdentifier: pid)
        let resolved = runningApplication?.localizedName ?? rawName
        let bundleName = runningApplication?.bundleURL?
            .deletingPathExtension()
            .lastPathComponent
        let combined = "\(resolved) \(bundleName ?? "") \(rawName)".lowercased()
        let iconPath = resolvedIconPath(for: runningApplication, pid: pid)

        let systemNames = [
            "launchd", "syslogd", "apsd", "usbmuxd", "dhcp6d", "airportd",
            "mdnsresponder", "wifip2pd", "rapportd", "controlcenter",
            "identityservice", "sharingd", "homed", "netbiosd", "nettop"
        ]
        if systemNames.contains(where: { combined.contains($0) }) { return nil }

        if combined.contains("google chrome") { return AppDescriptor(name: "Google Chrome", iconPath: iconPath) }
        if combined.contains("doubao browser") { return AppDescriptor(name: "豆包浏览器", iconPath: iconPath) }
        if combined.contains("feishu") || combined.contains("lark") { return AppDescriptor(name: "飞书", iconPath: iconPath) }
        if combined.contains("wechat") { return AppDescriptor(name: "微信", iconPath: iconPath) }
        if combined.contains("wpsoffice") || combined.contains("wps笔记") { return AppDescriptor(name: "WPS Office", iconPath: iconPath) }
        if combined.contains("onedrive") { return AppDescriptor(name: "OneDrive", iconPath: iconPath) }
        if combined.contains("chatgpt") { return AppDescriptor(name: "ChatGPT", iconPath: iconPath) }
        if combined.contains("codex") { return AppDescriptor(name: "Codex", iconPath: iconPath) }
        if combined.contains("termius") { return AppDescriptor(name: "Termius", iconPath: iconPath) }
        if combined.contains("rustdesk") { return AppDescriptor(name: "RustDesk", iconPath: iconPath) }
        if combined.contains("boostnet") || combined.contains("boostcore") { return AppDescriptor(name: "BoostNet", iconPath: iconPath) }
        if combined.contains("safari") { return AppDescriptor(name: "Safari", iconPath: iconPath) }
        if combined.contains("mail") { return AppDescriptor(name: "邮件", iconPath: iconPath) }

        var cleaned = bundleName ?? resolved
        if let helperRange = cleaned.range(of: " Helper", options: .caseInsensitive) {
            cleaned = String(cleaned[..<helperRange.lowerBound])
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.hasPrefix("com.apple.") else { return nil }
        return AppDescriptor(name: cleaned, iconPath: iconPath)
    }

    private static func resolvedIconPath(for application: NSRunningApplication?, pid: pid_t) -> String? {
        let candidates = [application?.bundleURL?.path, executablePath(pid: pid)].compactMap { $0 }

        for path in candidates {
            if let bundlePath = outerApplicationBundlePath(in: path) {
                return bundlePath
            }
        }

        return candidates.first
    }

    private static func executablePath(pid: pid_t) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE is 4 * MAXPATHLEN but is unavailable to
        // Swift in the macOS 27 SDK because it is expressed as a C macro.
        var buffer = [UInt8](repeating: 0, count: 4_096)
        let length = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(pid, bytes.baseAddress, UInt32(bytes.count))
        }
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func outerApplicationBundlePath(in path: String) -> String? {
        guard let marker = path.range(of: ".app", options: .caseInsensitive) else { return nil }
        return String(path[..<marker.upperBound])
    }
}

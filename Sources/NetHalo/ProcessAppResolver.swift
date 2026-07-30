import Darwin
import Foundation

struct ProcessAppDescriptor {
    let name: String
    let iconPath: String?
}

enum ProcessAppResolver {
    static func descriptor(
        rawName: String,
        pid: pid_t,
        includeSystemProcesses: Bool
    ) -> ProcessAppDescriptor? {
        let executable = executablePath(pid: pid) ?? (rawName.hasPrefix("/") ? rawName : nil)
        let bundlePath = [executable]
            .compactMap { $0 }
            .compactMap(outerApplicationBundlePath(in:))
            .first
        let bundleName = bundlePath.flatMap(displayName(forBundlePath:))
        let rawDisplayName = URL(fileURLWithPath: rawName).lastPathComponent
        let resolved = bundleName ?? rawDisplayName
        let combined = "\(resolved) \(bundlePath ?? "") \(rawName)".lowercased()
        let iconPath = bundlePath ?? executable

        let hiddenSystemNames = [
            "launchd", "syslogd", "apsd", "usbmuxd", "dhcp6d", "airportd",
            "mdnsresponder", "wifip2pd", "rapportd", "controlcenter",
            "identityservice", "sharingd", "homed", "netbiosd", "nettop"
        ]
        if !includeSystemProcesses,
           hiddenSystemNames.contains(where: { combined.contains($0) }) {
            return nil
        }

        if combined.contains("google chrome") { return ProcessAppDescriptor(name: "Google Chrome", iconPath: iconPath) }
        if combined.contains("doubao browser") { return ProcessAppDescriptor(name: "豆包浏览器", iconPath: iconPath) }
        if combined.contains("feishu") || combined.contains("lark") { return ProcessAppDescriptor(name: "飞书", iconPath: iconPath) }
        if combined.contains("wechat") { return ProcessAppDescriptor(name: "微信", iconPath: iconPath) }
        if combined.contains("wpsoffice") || combined.contains("wps笔记") { return ProcessAppDescriptor(name: "WPS Office", iconPath: iconPath) }
        if combined.contains("onedrive") { return ProcessAppDescriptor(name: "OneDrive", iconPath: iconPath) }
        if combined.contains("chatgpt") { return ProcessAppDescriptor(name: "ChatGPT", iconPath: iconPath) }
        if combined.contains("codex") { return ProcessAppDescriptor(name: "Codex", iconPath: iconPath) }
        if combined.contains("termius") { return ProcessAppDescriptor(name: "Termius", iconPath: iconPath) }
        if combined.contains("rustdesk") { return ProcessAppDescriptor(name: "RustDesk", iconPath: iconPath) }
        if combined.contains("boostnet") || combined.contains("boostcore") { return ProcessAppDescriptor(name: "BoostNet", iconPath: iconPath) }
        if combined.contains("safari") { return ProcessAppDescriptor(name: "Safari", iconPath: iconPath) }
        if combined.contains("mail") { return ProcessAppDescriptor(name: "邮件", iconPath: iconPath) }

        var cleaned = resolved
        if let helperRange = cleaned.range(of: " Helper", options: .caseInsensitive) {
            cleaned = String(cleaned[..<helperRange.lowerBound])
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if !includeSystemProcesses, cleaned.hasPrefix("com.apple.") { return nil }
        return ProcessAppDescriptor(name: cleaned, iconPath: iconPath)
    }

    private static func displayName(forBundlePath path: String) -> String? {
        guard let bundle = Bundle(path: path) else {
            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    private static func executablePath(pid: pid_t) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE is unavailable to Swift in the macOS 27 SDK.
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

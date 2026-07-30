import Foundation

struct MetricsSnapshot: Equatable {
    var cpuPercent: Double = 0
    var memoryPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0
    var sampledAt = Date()

    var health: SystemHealth {
        if cpuPercent >= 85 || memoryPercent >= 92 { return .busy }
        if cpuPercent >= 60 || memoryPercent >= 82 { return .working }
        return .calm
    }
}

enum SystemHealth: Equatable {
    case calm
    case working
    case busy

    var title: String {
        switch self {
        case .calm: return "轻松运行"
        case .working: return "正在忙碌"
        case .busy: return "负载较高"
        }
    }
}

struct NetworkAppMetric: Identifiable, Equatable {
    let name: String
    let iconPath: String?
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double

    var id: String { name }
    var totalBytesPerSecond: Double { downloadBytesPerSecond + uploadBytesPerSecond }
}

enum RateFormatter {
    static func menu(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)

        if value < 1_000 {
            return "0K"
        } else if value < 1_000_000 {
            return String(format: "%.0fK", value / 1_000)
        } else if value < 10_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value < 1_000_000_000 {
            return String(format: "%.0fM", value / 1_000_000)
        }

        return String(format: "%.1fG", value / 1_000_000_000)
    }

    static func detail(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)

        if value < 1_000 {
            return "0 KB/s"
        } else if value < 1_000_000 {
            return String(format: "%.0f KB/s", value / 1_000)
        } else if value < 100_000_000 {
            return String(format: "%.1f MB/s", value / 1_000_000)
        } else if value < 1_000_000_000 {
            return String(format: "%.0f MB/s", value / 1_000_000)
        }

        return String(format: "%.2f GB/s", value / 1_000_000_000)
    }
}

enum MemoryFormatter {
    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    static func process(_ bytes: UInt64) -> String {
        if bytes < 1_073_741_824 {
            return String(format: "%.0f MB", Double(bytes) / 1_048_576)
        }
        return gigabytes(bytes)
    }
}

extension Array where Element == Double {
    mutating func appendKeepingLast(_ value: Double, limit: Int) {
        append(value)
        if count > limit {
            removeFirst(count - limit)
        }
    }
}

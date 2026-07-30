import Darwin
import Foundation

enum SelfCheck {
    static func run() -> Int32 {
        var failures: [String] = []

        expect(RateFormatter.menu(0) == "0K", "零网速格式错误", failures: &failures)
        expect(RateFormatter.menu(850_000) == "850K", "KB 网速格式错误", failures: &failures)
        expect(RateFormatter.menu(1_250_000) == "1.2M", "MB 网速格式错误", failures: &failures)
        expect(RateFormatter.menu(1_500_000_000) == "1.5G", "GB 网速格式错误", failures: &failures)
        expect(CPUFormatter.process(3.25) == "3.2%", "低 CPU 占用格式错误", failures: &failures)
        expect(CPUFormatter.process(32.5) == "32%", "CPU 占用格式错误", failures: &failures)
        expect(MemoryFormatter.process(536_870_912) == "512 MB", "进程内存格式错误", failures: &failures)
        expect(DetailMetric(rawValue: "memory") == .memory, "详情类型恢复错误", failures: &failures)

        var history: [Double] = []
        for value in 0..<65 {
            history.appendKeepingLast(Double(value), limit: 60)
        }
        expect(history.count == 60, "趋势数据长度错误", failures: &failures)
        expect(history.first == 5 && history.last == 64, "趋势数据滚动错误", failures: &failures)

        expect(MetricsSnapshot(cpuPercent: 20, memoryPercent: 40).health.title == "轻松运行", "平稳阈值错误", failures: &failures)
        expect(MetricsSnapshot(cpuPercent: 65, memoryPercent: 40).health.title == "正在忙碌", "忙碌阈值错误", failures: &failures)
        expect(MetricsSnapshot(cpuPercent: 90, memoryPercent: 40).health.title == "负载较高", "高负载阈值错误", failures: &failures)

        let sampler = MetricsSampler()
        _ = sampler.sample()
        usleep(120_000)
        let live = sampler.sample()
        expect(live.memoryTotalBytes > 0, "未读取到物理内存", failures: &failures)
        expect((0...100).contains(live.cpuPercent), "CPU 采样超出范围", failures: &failures)
        expect((0...100).contains(live.memoryPercent), "内存采样超出范围", failures: &failures)
        expect(live.downloadBytesPerSecond >= 0 && live.uploadBytesPerSecond >= 0, "网速采样出现负数", failures: &failures)

        let nettopFixture = """
        ,bytes_in,bytes_out,
        Google Chrome H.99991,100000,10000,
        ,bytes_in,bytes_out,
        Google Chrome H.99991,4000,1000,
        Google Chrome H.99992,2000,500,
        ChatGPT.99993,1200,300,
        mDNSResponder.99994,9000,9000,
        """
        let apps = ProcessNetworkSampler.parseDeltaCSV(nettopFixture)
        expect(apps.count == 2, "分应用网速过滤或合并错误", failures: &failures)
        expect(apps.first?.name == "Google Chrome", "分应用网速排序错误", failures: &failures)
        expect(apps.first?.downloadBytesPerSecond == 6_000, "Helper 流量合并错误", failures: &failures)

        let processFixture = """
        99101 12.5 100000 Google Chrome Helper
        99102 7.5 50000 Google Chrome Helper
        99103 3.0 200000 WindowServer
        """
        let resources = ProcessResourceSampler.parsePSOutput(processFixture)
        expect(resources.topCPUApps.first?.name == "Google Chrome", "CPU 应用合并或排序错误", failures: &failures)
        expect(resources.topCPUApps.first?.cpuPercent == 20, "CPU Helper 合并错误", failures: &failures)
        expect(resources.topMemoryApps.first?.name == "WindowServer", "内存应用排序错误", failures: &failures)

        if failures.isEmpty {
            print("SELF_CHECK_PASS")
            return 0
        }

        for failure in failures {
            fputs("SELF_CHECK_FAIL: \(failure)\n", stderr)
        }
        return 1
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String, failures: inout [String]) {
        if !condition() {
            failures.append(message)
        }
    }
}

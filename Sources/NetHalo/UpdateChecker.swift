import Foundation

struct AppVersion: Comparable, Equatable {
    private let components: [Int]

    init?(_ value: String) {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var parsed: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            parsed.append(number)
        }
        components = parsed
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

enum UpdateCheckResult {
    case current(latestVersion: String)
    case updateAvailable(version: String, releaseURL: URL)
    case failed(message: String)
}

final class UpdateChecker {
    private static let latestReleaseURL = URL(
        string: "https://github.com/kermars39-web/NetHalo/releases/latest"
    )!

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: configuration)
    }

    func check(currentVersion: String, completion: @escaping (UpdateCheckResult) -> Void) {
        guard AppVersion(currentVersion) != nil else {
            completion(.failed(message: "无法识别当前版本"))
            return
        }

        var request = URLRequest(url: Self.latestReleaseURL)
        request.httpMethod = "HEAD"
        request.setValue("NetHalo/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { _, response, error in
            if error != nil {
                completion(.failed(message: "无法连接 GitHub，请检查网络"))
                return
            }

            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let releaseURL = http.url else {
                completion(.failed(message: "暂时无法获取最新版本"))
                return
            }

            completion(Self.evaluateRelease(url: releaseURL, currentVersion: currentVersion))
        }.resume()
    }

    static func evaluateRelease(url: URL, currentVersion: String) -> UpdateCheckResult {
        guard let installed = AppVersion(currentVersion) else {
            return .failed(message: "无法识别当前版本")
        }

        guard url.scheme == "https",
              url.host == "github.com",
              url.path.hasPrefix("/kermars39-web/NetHalo/releases/tag/"),
              let tag = url.pathComponents.last,
              let latest = AppVersion(tag) else {
            return .failed(message: "版本信息格式异常")
        }

        if installed < latest {
            return .updateAvailable(version: tag, releaseURL: url)
        }
        return .current(latestVersion: tag)
    }
}

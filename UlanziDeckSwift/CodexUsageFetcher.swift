import Foundation

nonisolated struct CodexUsageQuota: Equatable, Sendable {
    let remainingPercent: Int
    let resetAfterSeconds: Int

    var resetAfterText: String {
        let clampedSeconds = max(0, resetAfterSeconds)
        let days = clampedSeconds / 86_400
        let hours = clampedSeconds % 86_400 / 3_600
        let minutes = clampedSeconds % 3_600 / 60
        let clockText = "\(hours):\(String(format: "%02d", minutes))"
        return days > 0 ? "\(days)天 \(clockText)" : clockText
    }
}

nonisolated enum CodexUsageResult: Equatable, Sendable {
    case success(CodexUsageQuota)
    case authFileNotSelected
    case authFileNeedsReselection
    case invalidAuthFile
    case unauthorized
    case networkError(String)
}

nonisolated struct DeckKeyCodexUsageConfiguration: Codable, Equatable {
    static let defaultRefreshIntervalMinutes = 10
    static let refreshIntervalOptionsMinutes = [1, 5, 10, 30, 60]
    static let securityScopedBookmarkCreationOptions = DeckKeySecurityScopedBookmarkOptions.readOnlyCreation
    static let securityScopedBookmarkResolutionOptions = DeckKeySecurityScopedBookmarkOptions.resolution

    var authFilePath: String?
    var bookmarkData: Data?
    var refreshIntervalMinutes: Int

    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: CodexUsageResult?

    init(
        authFilePath: String? = nil,
        bookmarkData: Data? = nil,
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes,
        lastResult: CodexUsageResult? = nil
    ) {
        self.authFilePath = authFilePath
        self.bookmarkData = bookmarkData
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        self.lastResult = lastResult
    }

    init(
        authFileURL: URL,
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes
    ) throws {
        authFilePath = authFileURL.path
        bookmarkData = try authFileURL.bookmarkData(
            options: Self.securityScopedBookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        lastResult = nil
    }

    var needsReselection: Bool {
        authFilePath != nil && bookmarkData == nil
    }

    enum CodingKeys: CodingKey {
        case authFilePath
        case bookmarkData
        case refreshIntervalMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authFilePath = try container.decodeIfPresent(String.self, forKey: .authFilePath)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(
            try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes)
                ?? Self.defaultRefreshIntervalMinutes
        )
        lastResult = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(authFilePath, forKey: .authFilePath)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
    }

    static func normalizedRefreshIntervalMinutes(_ minutes: Int) -> Int {
        refreshIntervalOptionsMinutes.contains(minutes) ? minutes : defaultRefreshIntervalMinutes
    }
}

nonisolated protocol CodexUsageFetching: Sendable {
    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult
}

nonisolated enum CodexAuthFileLoadResult: Sendable {
    case success(Data)
    case notSelected
    case needsReselection
}

nonisolated protocol CodexAuthFileLoading: Sendable {
    func loadAuthData(
        configuration: DeckKeyCodexUsageConfiguration
    ) -> CodexAuthFileLoadResult
}

nonisolated struct SecurityScopedCodexAuthFileLoader: CodexAuthFileLoading {
    func loadAuthData(
        configuration: DeckKeyCodexUsageConfiguration
    ) -> CodexAuthFileLoadResult {
        guard let bookmarkData = configuration.bookmarkData else {
            return configuration.authFilePath == nil ? .notSelected : .needsReselection
        }

        do {
            var isStale = false
            let authFileURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: DeckKeyCodexUsageConfiguration.securityScopedBookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let didStartAccessing = authFileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    authFileURL.stopAccessingSecurityScopedResource()
                }
            }
            return .success(try Data(contentsOf: authFileURL))
        } catch {
            return .needsReselection
        }
    }
}

nonisolated struct CodexUsageFetcher: CodexUsageFetching {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval
    private let authFileLoader: CodexAuthFileLoading

    init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10,
        authFileLoader: CodexAuthFileLoading = SecurityScopedCodexAuthFileLoader()
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
        self.authFileLoader = authFileLoader
    }

    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult {
        let authData: Data
        switch authFileLoader.loadAuthData(configuration: configuration) {
        case let .success(data):
            authData = data
        case .notSelected:
            return .authFileNotSelected
        case .needsReselection:
            return .authFileNeedsReselection
        }

        guard let authObject = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = authObject["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty
        else {
            return .invalidAuthFile
        }

        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = tokens["account_id"] as? String, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        do {
            let response: URLResponse
            (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError("服务器响应无效")
            }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return .unauthorized
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                return .networkError("服务器返回 HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return .networkError(error.localizedDescription)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = object["rate_limit"] as? [String: Any],
              let primaryWindow = rateLimit["primary_window"] as? [String: Any],
              let remainingPercent = Self.remainingPercent(in: primaryWindow),
              let resetAfterSeconds = Self.nonnegativeInteger(from: primaryWindow["reset_after_seconds"])
        else {
            return .networkError("解析额度响应失败")
        }

        return .success(CodexUsageQuota(
            remainingPercent: remainingPercent,
            resetAfterSeconds: resetAfterSeconds
        ))
    }

    private static func remainingPercent(in value: Any?) -> Int? {
        guard let window = value as? [String: Any],
              let usedPercent = number(from: window["used_percent"])
        else {
            return nil
        }

        return min(100, max(0, Int(round(100 - usedPercent))))
    }

    private static func number(from value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func nonnegativeInteger(from value: Any?) -> Int? {
        guard let number = number(from: value), number.isFinite else {
            return nil
        }
        return max(0, Int(number.rounded(.down)))
    }
}

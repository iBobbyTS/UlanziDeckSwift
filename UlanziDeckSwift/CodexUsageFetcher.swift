import Foundation

nonisolated struct CodexUsageQuota: Equatable, Sendable {
    let remainingPercent: Int
    let resetAfterSeconds: Int
    let limitWindowSeconds: Int
    let usedPercent: Double

    var remainingTimeVsUsage: Double {
        let remainingWindowFraction = Double(resetAfterSeconds) / Double(limitWindowSeconds)
        let usedFraction = usedPercent * 0.01
        return remainingWindowFraction / usedFraction
    }

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

nonisolated enum CodexUsageColorMode: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case highIsRed
    case lowIsRed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highIsRed:
            return "量多标红"
        case .lowIsRed:
            return "量少标红"
        }
    }

    func metricColor(for remainingPercent: Int) -> MihoyoGameMetricColor {
        if remainingPercent > 95 {
            return self == .highIsRed ? .red : .green
        }
        if remainingPercent < 5 {
            return self == .highIsRed ? .green : .red
        }
        return .yellow
    }

    func resetTimeMetricColor(for remainingTimeVsUsage: Double) -> MihoyoGameMetricColor {
        if remainingTimeVsUsage < 0.9 {
            return self == .highIsRed ? .red : .green
        }
        if remainingTimeVsUsage > 1.1 {
            return self == .highIsRed ? .green : .red
        }
        return .yellow
    }
}

nonisolated struct DeckKeyCodexUsageConfiguration: Codable, Equatable {
    static let defaultRefreshIntervalMinutes = 10
    static let refreshIntervalOptionsMinutes = [1, 5, 10, 30, 60]
    static let securityScopedBookmarkCreationOptions = DeckKeySecurityScopedBookmarkOptions.readOnlyCreation
    static let securityScopedBookmarkResolutionOptions = DeckKeySecurityScopedBookmarkOptions.resolution

    static func defaultAuthFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json", isDirectory: false)
    }

    static func defaultAuthFileConfiguration(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> Self {
        try Self(authFileURL: defaultAuthFileURL(homeDirectory: homeDirectory))
    }

    var authFilePath: String?
    var bookmarkData: Data?
    var refreshIntervalMinutes: Int
    var colorMode: CodexUsageColorMode

    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: CodexUsageResult?

    init(
        authFilePath: String? = nil,
        bookmarkData: Data? = nil,
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes,
        colorMode: CodexUsageColorMode = .lowIsRed,
        lastResult: CodexUsageResult? = nil
    ) {
        self.authFilePath = authFilePath
        self.bookmarkData = bookmarkData
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        self.colorMode = colorMode
        self.lastResult = lastResult
    }

    init(
        authFileURL: URL,
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes,
        colorMode: CodexUsageColorMode = .lowIsRed
    ) throws {
        authFilePath = authFileURL.path
        bookmarkData = try authFileURL.bookmarkData(
            options: Self.securityScopedBookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        self.colorMode = colorMode
        lastResult = nil
    }

    var needsReselection: Bool {
        authFilePath != nil && bookmarkData == nil
    }

    enum CodingKeys: CodingKey {
        case authFilePath
        case bookmarkData
        case refreshIntervalMinutes
        case colorMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authFilePath = try container.decodeIfPresent(String.self, forKey: .authFilePath)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(
            try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes)
                ?? Self.defaultRefreshIntervalMinutes
        )
        colorMode = try container.decodeIfPresent(CodexUsageColorMode.self, forKey: .colorMode)
            ?? .lowIsRed
        lastResult = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(authFilePath, forKey: .authFilePath)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
        try container.encode(colorMode, forKey: .colorMode)
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
              let usedPercent = Self.finiteNumber(from: primaryWindow["used_percent"]),
              let resetAfterSeconds = Self.nonnegativeInteger(from: primaryWindow["reset_after_seconds"]),
              let limitWindowSeconds = Self.positiveInteger(from: primaryWindow["limit_window_seconds"])
        else {
            return .networkError("解析额度响应失败")
        }

        return .success(CodexUsageQuota(
            remainingPercent: Self.remainingPercent(from: usedPercent),
            resetAfterSeconds: resetAfterSeconds,
            limitWindowSeconds: limitWindowSeconds,
            usedPercent: usedPercent
        ))
    }

    private static func remainingPercent(from usedPercent: Double) -> Int {
        min(100, max(0, Int(round(100 - usedPercent))))
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
        guard let number = finiteNumber(from: value) else {
            return nil
        }
        return max(0, Int(number.rounded(.down)))
    }

    private static func positiveInteger(from value: Any?) -> Int? {
        guard let number = finiteNumber(from: value), number >= 1 else {
            return nil
        }
        return Int(number.rounded(.down))
    }

    private static func finiteNumber(from value: Any?) -> Double? {
        guard let number = number(from: value), number.isFinite else {
            return nil
        }
        return number
    }
}

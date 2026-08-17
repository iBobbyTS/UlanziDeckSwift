import Foundation

nonisolated enum CodexAuthSource: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case authFile
    case manualJSON

    var id: String { rawValue }

    var title: String {
        switch self {
        case .authFile:
            return "auth.json 文件"
        case .manualJSON:
            return "手动输入 JSON"
        }
    }
}

nonisolated struct CodexUsageQuota: Codable, Equatable, Sendable {
    let remainingPercent: Int
    let resetAfterSeconds: Int
    let resetAt: Int?
    let limitWindowSeconds: Int
    let usedPercent: Double

    init(
        remainingPercent: Int,
        resetAfterSeconds: Int,
        resetAt: Int? = nil,
        limitWindowSeconds: Int,
        usedPercent: Double
    ) {
        self.remainingPercent = remainingPercent
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
        self.limitWindowSeconds = limitWindowSeconds
        self.usedPercent = usedPercent
    }

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

    func resetAtText(timeZone: TimeZone = .current) -> String? {
        guard let resetAt else {
            return nil
        }

        let date = Date(timeIntervalSince1970: TimeInterval(resetAt))
        let components = Calendar(identifier: .gregorian).dateComponents(in: timeZone, from: date)
        guard let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute
        else {
            return nil
        }

        return String(format: "%d/%d %d:%02d", month, day, hour, minute)
    }
}

nonisolated enum CodexUsageResult: Codable, Equatable, Sendable {
    case success(CodexUsageQuota)
    case authFileNotSelected
    case authFileNeedsReselection
    case invalidAuthFile
    case unsupportedAuthMode
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

nonisolated enum CodexUsageResetDisplayMode: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case remainingTime
    case resetTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remainingTime:
            return "剩余时间"
        case .resetTime:
            return "重置时间"
        }
    }

    func text(for quota: CodexUsageQuota) -> String {
        switch self {
        case .remainingTime:
            return quota.resetAfterText
        case .resetTime:
            return quota.resetAtText() ?? quota.resetAfterText
        }
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

    var authSource: CodexAuthSource
    var authFilePath: String?
    var bookmarkData: Data?
    var manualAuthData: String
    var accountNickname: String
    var refreshIntervalMinutes: Int
    var colorMode: CodexUsageColorMode
    var resetDisplayMode: CodexUsageResetDisplayMode
    var visual: DeckKeyVisualConfiguration

    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: CodexUsageResult?
    var lastSuccessfulSnapshot: CodexUsageResult?
    var lastSuccessfulRefreshAt: Date?

    init(
        authSource: CodexAuthSource = .authFile,
        authFilePath: String? = nil,
        bookmarkData: Data? = nil,
        manualAuthData: String = "",
        accountNickname: String = "",
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes,
        colorMode: CodexUsageColorMode = .highIsRed,
        resetDisplayMode: CodexUsageResetDisplayMode = .remainingTime,
        visual: DeckKeyVisualConfiguration = DeckKeyVisualConfiguration(),
        lastResult: CodexUsageResult? = nil,
        lastSuccessfulRefreshAt: Date? = nil
        , lastSuccessfulSnapshot: CodexUsageResult? = nil
    ) {
        self.authSource = authSource
        self.authFilePath = authFilePath
        self.bookmarkData = bookmarkData
        self.manualAuthData = manualAuthData
        self.accountNickname = accountNickname
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        self.colorMode = colorMode
        self.resetDisplayMode = resetDisplayMode
        self.visual = visual
        self.lastResult = lastResult
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
        if let lastSuccessfulSnapshot {
            self.lastSuccessfulSnapshot = lastSuccessfulSnapshot
        } else {
            self.lastSuccessfulSnapshot = {
                guard case .success = lastResult else { return nil }
                return lastResult
            }()
        }
    }

    init(
        authFileURL: URL,
        accountNickname: String = "",
        refreshIntervalMinutes: Int = Self.defaultRefreshIntervalMinutes,
        colorMode: CodexUsageColorMode = .highIsRed,
        resetDisplayMode: CodexUsageResetDisplayMode = .remainingTime,
        visual: DeckKeyVisualConfiguration = DeckKeyVisualConfiguration()
    ) throws {
        authSource = .authFile
        authFilePath = authFileURL.path
        manualAuthData = ""
        self.accountNickname = accountNickname
        bookmarkData = try authFileURL.bookmarkData(
            options: Self.securityScopedBookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(refreshIntervalMinutes)
        self.colorMode = colorMode
        self.resetDisplayMode = resetDisplayMode
        self.visual = visual
        lastResult = nil
    }

    var needsReselection: Bool {
        authFilePath != nil && bookmarkData == nil
    }

    var displayAccountNickname: String? {
        let normalized = accountNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    enum CodingKeys: CodingKey {
        case authSource
        case authFilePath
        case bookmarkData
        case manualAuthData
        case accountNickname
        case refreshIntervalMinutes
        case colorMode
        case resetDisplayMode
        case visual
        case lastSuccessfulSnapshot
        case lastSuccessfulRefreshAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authSource = try container.decodeIfPresent(CodexAuthSource.self, forKey: .authSource) ?? .authFile
        authFilePath = try container.decodeIfPresent(String.self, forKey: .authFilePath)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        manualAuthData = try container.decodeIfPresent(String.self, forKey: .manualAuthData) ?? ""
        accountNickname = try container.decodeIfPresent(String.self, forKey: .accountNickname) ?? ""
        refreshIntervalMinutes = Self.normalizedRefreshIntervalMinutes(
            try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes)
                ?? Self.defaultRefreshIntervalMinutes
        )
        colorMode = try container.decodeIfPresent(CodexUsageColorMode.self, forKey: .colorMode)
            ?? .highIsRed
        resetDisplayMode = try container.decodeIfPresent(
            CodexUsageResetDisplayMode.self,
            forKey: .resetDisplayMode
        ) ?? .remainingTime
        visual = try container.decodeIfPresent(
            DeckKeyVisualConfiguration.self,
            forKey: .visual
        ) ?? DeckKeyVisualConfiguration()
        lastSuccessfulSnapshot = try container.decodeIfPresent(CodexUsageResult.self, forKey: .lastSuccessfulSnapshot)
        if case .success = lastSuccessfulSnapshot {} else { lastSuccessfulSnapshot = nil }
        lastResult = lastSuccessfulSnapshot
        lastSuccessfulRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulRefreshAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authSource, forKey: .authSource)
        try container.encodeIfPresent(authFilePath, forKey: .authFilePath)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(manualAuthData, forKey: .manualAuthData)
        try container.encode(accountNickname, forKey: .accountNickname)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
        try container.encode(colorMode, forKey: .colorMode)
        try container.encode(resetDisplayMode, forKey: .resetDisplayMode)
        try container.encode(visual, forKey: .visual)
        try container.encodeIfPresent(lastSuccessfulSnapshot, forKey: .lastSuccessfulSnapshot)
        try container.encodeIfPresent(lastSuccessfulRefreshAt, forKey: .lastSuccessfulRefreshAt)
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
        if configuration.authSource == .manualJSON {
            let trimmed = configuration.manualAuthData.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .authFileNotSelected
            }
            guard let data = trimmed.data(using: .utf8) else {
                return .invalidAuthFile
            }
            authData = data
        } else {
            switch authFileLoader.loadAuthData(configuration: configuration) {
            case let .success(data):
                authData = data
            case .notSelected:
                return .authFileNotSelected
            case .needsReselection:
                return .authFileNeedsReselection
            }
        }

        guard let authObject = try? JSONSerialization.jsonObject(with: authData) as? [String: Any]
        else {
            return .invalidAuthFile
        }

        let authMode = authObject["auth_mode"] as? String ?? ""
        if authMode != "chatgpt" {
            return .unsupportedAuthMode
        }

        guard let tokens = authObject["tokens"] as? [String: Any],
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
            resetAt: Self.nonnegativeInteger(from: primaryWindow["reset_at"]),
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

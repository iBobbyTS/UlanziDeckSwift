import Foundation
import Security

nonisolated enum AntigravityTokenLoadResult: Sendable {
    case success(String)
    case notLoggedIn
    case invalid
}

nonisolated protocol AntigravityTokenLoading: Sendable {
    func loadAccessToken() -> AntigravityTokenLoadResult
}

/// Antigravity CLI 在 login keychain 中存放的 OAuth token：
/// service "gemini"、account "antigravity"，内容为 "go-keyring-base64:" 前缀
/// 加 base64 编码的 JSON，其中 token.access_token 为 Google OAuth 访问令牌。
nonisolated struct KeychainAntigravityTokenLoader: AntigravityTokenLoading {
    private static let goKeyringBase64Prefix = "go-keyring-base64:"

    func loadAccessToken() -> AntigravityTokenLoadResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gemini",
            kSecAttrAccount as String: "antigravity",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let rawValue = String(data: data, encoding: .utf8)
        else {
            return .notLoggedIn
        }

        let payload = rawValue.hasPrefix(Self.goKeyringBase64Prefix)
            ? String(rawValue.dropFirst(Self.goKeyringBase64Prefix.count))
            : rawValue
        guard let decodedData = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
              let token = object["token"] as? [String: Any],
              let accessToken = token["access_token"] as? String,
              !accessToken.isEmpty
        else {
            return .invalid
        }
        return .success(accessToken)
    }
}

nonisolated protocol AntigravityUsageFetching: Sendable {
    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult
}

nonisolated struct AntigravityUsageFetcher: AntigravityUsageFetching {
    private static let quotaSummaryURL = URL(
        string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
    )!
    private static let userAgent = "antigravity/1.20.5 darwin/arm64 google-api-nodejs-client/10.3.0"
    private static let fiveHourWindowSeconds = 18_000
    private static let weeklyWindowSeconds = 604_800

    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval
    private let tokenLoader: AntigravityTokenLoading
    private let now: @Sendable () -> Date

    init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10,
        tokenLoader: AntigravityTokenLoading = KeychainAntigravityTokenLoader(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
        self.tokenLoader = tokenLoader
        self.now = now
    }

    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult {
        let accessToken: String
        switch tokenLoader.loadAccessToken() {
        case let .success(token):
            accessToken = token
        case .notLoggedIn:
            return .authFileNotSelected
        case .invalid:
            return .invalidAuthFile
        }

        var request = URLRequest(url: Self.quotaSummaryURL)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

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
              let groups = object["groups"] as? [[String: Any]]
        else {
            return .networkError("解析额度响应失败")
        }

        let buckets = groups.flatMap { $0["buckets"] as? [[String: Any]] ?? [] }
        let familyPrefix = configuration.antigravityModelFamily == .gemini ? "gemini-" : "3p-"
        let specifications: [(window: UsageQuotaWindow, bucketSuffix: String, limitWindowSeconds: Int)] = [
            (.fiveHours, "5h", Self.fiveHourWindowSeconds),
            (.sevenDays, "weekly", Self.weeklyWindowSeconds),
        ]

        let requestTime = now()
        let quotas = specifications.compactMap { specification -> CodexUsageQuota? in
            guard configuration.antigravityModelFamily == .gemini
                    || specification.window == .sevenDays
            else {
                return nil
            }
            guard let bucket = buckets.first(where: {
                ($0["bucketId"] as? String)?.hasPrefix(familyPrefix) == true
                    && ($0["bucketId"] as? String)?.hasSuffix(specification.bucketSuffix) == true
            }), let fraction = Self.finiteNumber(bucket["remainingFraction"])
            else {
                return nil
            }

            let remainingPercent = min(100, max(0, Int((fraction * 100).rounded())))
            let resetAt = Self.resetAtSeconds(fromISO8601String: bucket["resetTime"])
            return CodexUsageQuota(
                window: specification.window,
                remainingPercent: remainingPercent,
                resetAfterSeconds: resetAt.map { max(0, $0 - Int(requestTime.timeIntervalSince1970)) } ?? 0,
                resetAt: resetAt,
                limitWindowSeconds: specification.limitWindowSeconds,
                usedPercent: 100 - Double(remainingPercent)
            )
        }
        guard !quotas.isEmpty else {
            return .missingWeeklyQuota
        }
        return .success(UsageQuotaSnapshot(quotas: quotas))
    }

    private static func resetAtSeconds(fromISO8601String value: Any?) -> Int? {
        guard let string = value as? String else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
        else {
            return nil
        }
        return Int(date.timeIntervalSince1970.rounded(.down))
    }

    private static func finiteNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              number.doubleValue.isFinite,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else {
            return nil
        }
        return number.doubleValue
    }
}

import Foundation
import Security

/// Go time.Time 的 JSON 序列化是 RFC3339，小数秒位数不定（RFC3339Nano 会裁掉
/// 尾零），与额度响应里的 resetTime 是同一格式。ISO8601DateFormatter 的
/// withFractionalSeconds 不保证兼容任意位数，因此手动剥出小数秒再解析。
nonisolated enum AntigravityISO8601Parsing {
    private static let formatter = ISO8601DateFormatter()

    static func date(from string: String) -> Date? {
        if let date = formatter.date(from: string) {
            return date
        }
        guard let dotIndex = string.firstIndex(of: ".") else {
            return nil
        }
        var fractionEnd = string.index(after: dotIndex)
        while fractionEnd < string.endIndex, string[fractionEnd].isNumber {
            fractionEnd = string.index(after: fractionEnd)
        }
        let fractionDigits = string[string.index(after: dotIndex)..<fractionEnd]
        guard !fractionDigits.isEmpty,
              let fraction = Double("0.\(fractionDigits)")
        else {
            return nil
        }
        var base = string
        base.removeSubrange(dotIndex..<fractionEnd)
        guard let date = formatter.date(from: base) else {
            return nil
        }
        return date.addingTimeInterval(fraction)
    }
}

nonisolated struct AntigravityStoredToken: Sendable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiry: Date?

    init(accessToken: String, refreshToken: String? = nil, expiry: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiry = expiry
    }
}

/// 副本条目的 JSON 编码格式。expiry 用 ISO8601 字符串（无小数秒），
/// 解析复用 {@link AntigravityISO8601Parsing}，因此手工修复副本时也能写
/// Go 风格的带小数秒时间。
nonisolated extension AntigravityStoredToken: Codable {
    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiry
    }

    private static let expiryFormatter = ISO8601DateFormatter()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            accessToken: try container.decode(String.self, forKey: .accessToken),
            refreshToken: try container.decodeIfPresent(String.self, forKey: .refreshToken),
            expiry: try container.decodeIfPresent(String.self, forKey: .expiry)
                .flatMap { AntigravityISO8601Parsing.date(from: $0) }
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(
            expiry.map { Self.expiryFormatter.string(from: $0) },
            forKey: .expiry
        )
    }
}

nonisolated enum AntigravityTokenLoadResult: Sendable {
    case success(AntigravityStoredToken)
    case notLoggedIn
    case invalid
}

nonisolated protocol AntigravityTokenLoading: Sendable {
    func loadStoredToken() -> AntigravityTokenLoadResult
}

/// Antigravity CLI 在 login keychain 中存放的 OAuth token：
/// service "gemini"、account "antigravity"，内容为 "go-keyring-base64:" 前缀
/// 加 base64 编码的 JSON，其中 token 对象含 access_token / refresh_token / expiry。
nonisolated struct KeychainAntigravityTokenLoader: AntigravityTokenLoading {
    private static let goKeyringBase64Prefix = "go-keyring-base64:"

    func loadStoredToken() -> AntigravityTokenLoadResult {
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
        let refreshToken = (token["refresh_token"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let expiry = (token["expiry"] as? String).flatMap { AntigravityISO8601Parsing.date(from: $0) }
        return .success(AntigravityStoredToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: expiry
        ))
    }
}

nonisolated protocol AntigravityTokenStoring: Sendable {
    /// 无副本或读取失败时返回 nil，调用方会回退到读取 agy CLI 的条目。
    func loadToken() -> AntigravityStoredToken?
    /// 写入失败只影响下次需要同步的时机，不阻断本次查询，因此静默降级。
    func saveToken(_ token: AntigravityStoredToken)
    func deleteToken()
}

/// 本应用自有的 Antigravity token 副本条目。agy CLI 刷新 token 后用
/// `security add-generic-password -U`（不带 -T）回写它自己的条目，该操作会
/// 重置条目的 ACL 信任列表，本应用此前获得的"始终允许"授权随之丢失，导致
/// 授权弹窗反复出现。副本条目由本应用创建，应用对自己的条目始终静默读写
/// （按签名身份匹配，覆盖构建后依然有效），额度查询因此与 agy 的回写解耦。
nonisolated struct KeychainAntigravityTokenStore: AntigravityTokenStoring {
    private static let service = "com.iBobby.UlanziDeckSwift.antigravity"
    private static let account = "token"

    func loadToken() -> AntigravityStoredToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(AntigravityStoredToken.self, from: data)
    }

    func saveToken(_ token: AntigravityStoredToken) {
        guard let data = try? JSONEncoder().encode(token) else {
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        SecItemDelete(query as CFDictionary)
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
    private static let tokenRefreshURL = URL(string: "https://oauth2.googleapis.com/token")!
    /// agy CLI 内置的 Antigravity OAuth 客户端。installed-app 凭据随官方二进制公开分发，
    /// 钥匙串里的 refresh_token 即由该客户端签发，只有同一客户端能刷新。
    private static let oauthClientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    private static let oauthClientSecret = "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"
    /// 距过期不足 5 分钟就提前刷新，避免边界上拿到刚失效的 access token。
    private static let tokenRefreshLeadSeconds: TimeInterval = 300

    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval
    private let tokenLoader: AntigravityTokenLoading
    private let tokenStore: AntigravityTokenStoring
    private let now: @Sendable () -> Date

    init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10,
        tokenLoader: AntigravityTokenLoading = KeychainAntigravityTokenLoader(),
        tokenStore: AntigravityTokenStoring = KeychainAntigravityTokenStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
        self.tokenLoader = tokenLoader
        self.tokenStore = tokenStore
        self.now = now
    }

    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult {
        let accessToken: String
        switch await resolveWorkingToken() {
        case let .success(token):
            accessToken = token
        case let .failure(result):
            return result
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

    private enum ResolvedAccessToken {
        case success(String)
        case failure(CodexUsageResult)
    }

    /// 额度查询的 token 来源：优先读写本应用自己的副本条目，与 agy CLI 的条目
    /// 解耦（agy 回写时会重置它条目的 ACL，见 {@link KeychainAntigravityTokenStore}）。
    /// 仅当副本不存在，或副本中的 refresh_token 失效需要重新同步时，才回读 agy
    /// 的条目——此时可能弹一次授权窗。
    private func resolveWorkingToken() async -> ResolvedAccessToken {
        if let storedToken = tokenStore.loadToken() {
            return await resolveAccessToken(for: storedToken, fromOwnStore: true)
        }
        return await adoptSourceToken()
    }

    /// 无副本时从 agy CLI 的条目读取 token，解析结果会写入副本供后续查询使用。
    private func adoptSourceToken() async -> ResolvedAccessToken {
        let sourceToken: AntigravityStoredToken
        switch tokenLoader.loadStoredToken() {
        case let .success(token):
            sourceToken = token
        case .notLoggedIn:
            return .failure(.authFileNotSelected)
        case .invalid:
            return .failure(.invalidAuthFile)
        }
        return await resolveAccessToken(for: sourceToken, fromOwnStore: false)
    }

    /// access token 已知仍有效（距过期超过缓冲量）时直接使用；否则用 refresh_token
    /// 向 Google 换新并回写副本。Google 允许同一 refresh_token 被本应用与 agy CLI
    /// 并发换发 access token，互不影响。没有 refresh_token 时退回存量 token，
    /// 保持直接查询的旧行为。
    private func resolveAccessToken(
        for storedToken: AntigravityStoredToken,
        fromOwnStore: Bool,
        allowResync: Bool = true
    ) async -> ResolvedAccessToken {
        var resolvedToken = storedToken
        let isFresh = storedToken.expiry
            .map { $0.timeIntervalSince(now()) > Self.tokenRefreshLeadSeconds }
            ?? false
        if !isFresh {
            switch await refreshAccessToken(for: storedToken) {
            case let .success(accessToken, expiresInSeconds):
                resolvedToken = AntigravityStoredToken(
                    accessToken: accessToken,
                    refreshToken: storedToken.refreshToken,
                    expiry: expiresInSeconds.map { now().addingTimeInterval($0) }
                )
            case .notPossible:
                break
            case .invalidGrant:
                if fromOwnStore, allowResync {
                    return await resyncAfterInvalidGrant(staleRefreshToken: storedToken.refreshToken)
                }
                // token 刚从 agy 条目读出就 invalid_grant，说明授权本身已失效，
                // 重新读取同一来源也不会有变化。
                return .failure(.unauthorized)
            case let .networkError(message):
                return .failure(.networkError(message))
            }
        }
        if !fromOwnStore || resolvedToken != storedToken {
            tokenStore.saveToken(resolvedToken)
        }
        return .success(resolvedToken.accessToken)
    }

    /// 副本中的 refresh_token 失效（例如用户吊销授权后重新登录 agy）时，删除副本
    /// 并回读 agy 条目。只有源的 refresh_token 与失效的不同才重新采用，避免对同一
    /// 个失效授权反复刷新；源不可用或未变化时按登录失效处理。
    private func resyncAfterInvalidGrant(staleRefreshToken: String?) async -> ResolvedAccessToken {
        tokenStore.deleteToken()
        guard case let .success(sourceToken) = tokenLoader.loadStoredToken(),
              sourceToken.refreshToken != staleRefreshToken
        else {
            return .failure(.unauthorized)
        }
        return await resolveAccessToken(for: sourceToken, fromOwnStore: false, allowResync: false)
    }

    private enum RefreshedAccessToken {
        case success(accessToken: String, expiresInSeconds: TimeInterval?)
        case notPossible
        case invalidGrant
        case networkError(String)
    }

    private func refreshAccessToken(for storedToken: AntigravityStoredToken) async -> RefreshedAccessToken {
        guard let refreshToken = storedToken.refreshToken else {
            return .notPossible
        }

        var request = URLRequest(url: Self.tokenRefreshURL)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: Self.oauthClientID),
            URLQueryItem(name: "client_secret", value: Self.oauthClientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        do {
            let response: URLResponse
            (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError("服务器响应无效")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   (object["error"] as? String) == "invalid_grant" {
                    return .invalidGrant
                }
                return .networkError("服务器返回 HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return .networkError(error.localizedDescription)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = object["access_token"] as? String,
              !accessToken.isEmpty
        else {
            return .networkError("解析刷新响应失败")
        }
        return .success(
            accessToken: accessToken,
            expiresInSeconds: Self.finiteNumber(object["expires_in"])
        )
    }

    private static func resetAtSeconds(fromISO8601String value: Any?) -> Int? {
        guard let string = value as? String,
              let date = AntigravityISO8601Parsing.date(from: string)
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

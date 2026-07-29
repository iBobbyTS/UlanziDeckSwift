import Foundation

// MARK: - 认证信息模型

/// Sub2API 认证信息，包含 access token、refresh token 和过期时间戳。
/// 用于支持 JWT token 的自动刷新。
nonisolated struct Sub2APIAuthInfo: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var tokenExpiresAt: Int64

    private static let refreshBufferMs: Int64 = 120_000

    var isExpiringSoon: Bool {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return now >= tokenExpiresAt - Self.refreshBufferMs
    }

    var isExpired: Bool {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return now >= tokenExpiresAt
    }

    /// 从浏览器获取的 JSON 字符串解析认证信息。
    static func parse(from jsonString: String) -> Sub2APIAuthInfo? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              !accessToken.isEmpty,
              !refreshToken.isEmpty
        else {
            return nil
        }

        let expiresAt: Int64
        if let expiresAtStr = json["expires_at"] as? String, let parsed = Int64(expiresAtStr) {
            expiresAt = parsed
        } else if let expiresAtNum = json["expires_at"] as? Int64 {
            expiresAt = expiresAtNum
        } else {
            return nil
        }

        return Sub2APIAuthInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiresAt: expiresAt
        )
    }

    /// 将认证信息序列化为 JSON 字符串，用于存储。
    func jsonString() -> String? {
        let dict: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "expires_at": String(tokenExpiresAt),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }
}

// MARK: - 数据模型

/// Sub2API 容量摘要的 API 响应根结构体。
nonisolated struct Sub2APICapacityResponse: Decodable, Equatable {
    let code: Sub2APIResponseCode
    let message: String
    let data: Sub2APICapacityData?

    enum CodingKeys: CodingKey {
        case code
        case message
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawCode: Sub2APIResponseCode
        if let integerCode = try? container.decode(Int.self, forKey: .code) {
            rawCode = Sub2APIResponseCode(integerValue: integerCode)
        } else {
            rawCode = Sub2APIResponseCode(rawValue: try container.decode(String.self, forKey: .code))
        }
        let message = try container.decode(String.self, forKey: .message)

        if rawCode == .success {
            code = .success
            data = try container.decodeIfPresent(Sub2APICapacityData.self, forKey: .data)
        } else {
            code = rawCode
            data = nil
        }

        self.message = message
    }

    var indicatesInvalidToken: Bool {
        code == .invalidToken
            || message.localizedCaseInsensitiveContains("INVALID_TOKEN")
            || message.localizedCaseInsensitiveContains("invalid token")
    }

    var indicatesTokenExpired: Bool {
        code == .tokenExpired
            || message.localizedCaseInsensitiveContains("TOKEN_EXPIRED")
            || message.localizedCaseInsensitiveContains("expired")
    }
}

/// API 响应码。业务码 0 表示成功；错误码可能是数字，也可能是字符串。
nonisolated struct Sub2APIResponseCode: Equatable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(integerValue: Int) {
        self.rawValue = "\(integerValue)"
    }

    static let success = Sub2APIResponseCode(rawValue: "0")
    static let invalidToken = Sub2APIResponseCode(rawValue: "INVALID_TOKEN")
    static let tokenExpired = Sub2APIResponseCode(rawValue: "TOKEN_EXPIRED")
}

/// 容量摘要数据容器。
nonisolated struct Sub2APICapacityData: Decodable, Equatable {
    let items: [Sub2APICapacityItem]
    let total: Sub2APICapacityItem
}

/// 单个分组（或汇总）的容量信息。
nonisolated struct Sub2APICapacityItem: Decodable, Equatable {
    let groupID: Int
    let groupName: String
    let groupPlatform: String
    let concurrencyUsed: Int
    let concurrencyMax: Int
    let sessionsUsed: Int
    let sessionsMax: Int
    let rpmUsed: Int
    let rpmMax: Int

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case groupName = "group_name"
        case groupPlatform = "group_platform"
        case concurrencyUsed = "concurrency_used"
        case concurrencyMax = "concurrency_max"
        case sessionsUsed = "sessions_used"
        case sessionsMax = "sessions_max"
        case rpmUsed = "rpm_used"
        case rpmMax = "rpm_max"
    }

    var availableConcurrency: Int {
        concurrencyMax - concurrencyUsed
    }
}

// MARK: - 请求结果

nonisolated enum Sub2APICapacityResult: Equatable {
    case success(item: Sub2APICapacityItem)
    case invalidToken
    case tokenExpired
    case notFound
    case networkError(String)
}

nonisolated enum Sub2APIGroupListResult: Equatable {
    case success(items: [Sub2APICapacityItem])
    case invalidToken
    case tokenExpired
    case networkError(String)
}

private nonisolated struct Sub2APIFetchError: Error {
    let message: String
    let isUnauthorized: Bool

    init(message: String, isUnauthorized: Bool = false) {
        self.message = message
        self.isUnauthorized = isUnauthorized
    }
}

nonisolated enum Sub2APIBaseURLError: Error {
    case invalid
}

nonisolated struct Sub2APIBaseURL: Equatable {
    private static let capacitySummaryPathComponents = [
        "api",
        "v1",
        "channel-monitors",
        "capacity-summary",
    ]
    private static let refreshPathComponents = [
        "api",
        "v1",
        "auth",
        "refresh",
    ]

    let url: URL
    let host: String

    init(_ rawValue: String) throws {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw Sub2APIBaseURLError.invalid
        }

        let urlString = trimmedValue.contains("://") ? trimmedValue : "https://\(trimmedValue)"
        guard var components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.host,
              !host.isEmpty
        else {
            throw Sub2APIBaseURLError.invalid
        }

        components.scheme = "https"
        components.path = Self.normalizedPath(components.path)

        guard let url = components.url else {
            throw Sub2APIBaseURLError.invalid
        }

        self.url = url
        self.host = host
    }

    var capacitySummaryURL: URL {
        Self.capacitySummaryPathComponents.reduce(url) { partialURL, pathComponent in
            partialURL.appendingPathComponent(pathComponent)
        }
    }

    var refreshTokenURL: URL {
        Self.refreshPathComponents.reduce(url) { partialURL, pathComponent in
            partialURL.appendingPathComponent(pathComponent)
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        guard path != "/" else {
            return ""
        }

        var normalizedPath = path
        while normalizedPath.hasSuffix("/") {
            normalizedPath.removeLast()
        }

        return normalizedPath
    }
}

// MARK: - Token 刷新模型

nonisolated struct Sub2APIRefreshResponse: Decodable {
    let code: Int
    let message: String?
    let data: Sub2APIRefreshData?

    struct Sub2APIRefreshData: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    enum CodingKeys: String, CodingKey {
        case code, message, data
    }
}

// MARK: - 网络服务协议与实现

nonisolated protocol Sub2APIFetching: Sendable {
    func fetchCapacitySummary(baseURL: String, targetGroupID: Int, bearerKey: String) async -> Sub2APICapacityResult
    func fetchCapacityGroups(baseURL: String, bearerKey: String) async -> Sub2APIGroupListResult
    func refreshBearerToken(baseURL: String, refreshToken: String) async -> Sub2APIAuthInfo?
}

nonisolated struct Sub2APIFetcher: Sub2APIFetching {
    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval

    nonisolated init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
    }

    func fetchCapacitySummary(baseURL: String, targetGroupID: Int, bearerKey: String) async -> Sub2APICapacityResult {
        let responseResult = await fetchCapacityResponse(baseURL: baseURL, bearerKey: bearerKey)
        guard case let .success(response) = responseResult else {
            if case let .failure(error) = responseResult {
                if error.isUnauthorized {
                    return .invalidToken
                }
                return .networkError(error.message)
            }

            return .networkError("未知错误")
        }

        guard response.code == .success, let items = response.data?.items else {
            if response.indicatesInvalidToken {
                return .invalidToken
            }

            if response.indicatesTokenExpired {
                return .tokenExpired
            }

            return .networkError(response.message)
        }

        guard let targetItem = items.first(where: { $0.groupID == targetGroupID }) else {
            return .notFound
        }

        return .success(item: targetItem)
    }

    func fetchCapacityGroups(baseURL: String, bearerKey: String) async -> Sub2APIGroupListResult {
        let responseResult = await fetchCapacityResponse(baseURL: baseURL, bearerKey: bearerKey)
        guard case let .success(response) = responseResult else {
            if case let .failure(error) = responseResult {
                if error.isUnauthorized {
                    return .invalidToken
                }
                return .networkError(error.message)
            }

            return .networkError("未知错误")
        }

        guard response.code == .success, let items = response.data?.items else {
            if response.indicatesInvalidToken {
                return .invalidToken
            }

            if response.indicatesTokenExpired {
                return .tokenExpired
            }

            return .networkError(response.message)
        }

        return .success(items: items)
    }

    private func fetchCapacityResponse(baseURL: String, bearerKey: String) async -> Result<Sub2APICapacityResponse, Sub2APIFetchError> {
        let url: URL
        do {
            url = try Sub2APIBaseURL(baseURL).capacitySummaryURL
        } catch {
            return .failure(Sub2APIFetchError(message: "无效的 Base URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let data: Data
        do {
            data = try await AuthenticatedHTTPResponseLoader.data(
                for: request,
                urlSession: urlSession
            )
        } catch AuthenticatedHTTPResponseError.unauthorized {
            return .failure(Sub2APIFetchError(
                message: AuthenticatedHTTPResponseError.unauthorized.localizedDescription,
                isUnauthorized: true
            ))
        } catch {
            return .failure(Sub2APIFetchError(message: error.localizedDescription))
        }

        do {
            let decoder = JSONDecoder()
            return .success(try decoder.decode(Sub2APICapacityResponse.self, from: data))
        } catch {
            return .failure(Sub2APIFetchError(message: "解析响应失败：\(error.localizedDescription)"))
        }
    }

    func refreshBearerToken(baseURL: String, refreshToken: String) async -> Sub2APIAuthInfo? {
        let url: URL
        do {
            url = try Sub2APIBaseURL(baseURL).refreshTokenURL
        } catch {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds

        let body: [String: String] = ["refresh_token": refreshToken]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        request.httpBody = bodyData

        let data: Data
        do {
            let (responseData, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                return nil
            }
            data = responseData
        } catch {
            return nil
        }

        guard let refreshResponse = try? JSONDecoder().decode(Sub2APIRefreshResponse.self, from: data),
              refreshResponse.code == 0,
              let refreshData = refreshResponse.data
        else {
            return nil
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return Sub2APIAuthInfo(
            accessToken: refreshData.accessToken,
            refreshToken: refreshData.refreshToken,
            tokenExpiresAt: now + Int64(refreshData.expiresIn) * 1000
        )
    }
}

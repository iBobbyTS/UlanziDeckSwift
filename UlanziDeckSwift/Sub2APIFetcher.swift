import Foundation

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

        let rawCode = try container.decode(Int.self, forKey: .code)
        let message = try container.decode(String.self, forKey: .message)

        if rawCode == 0 {
            code = .success
            data = try container.decodeIfPresent(Sub2APICapacityData.self, forKey: .data)
        } else {
            code = Sub2APIResponseCode(rawValue: rawCode)
            data = nil
        }

        self.message = message
    }

    var indicatesTokenExpired: Bool {
        message.localizedCaseInsensitiveContains("TOKEN_EXPIRED")
            || message.localizedCaseInsensitiveContains("expired")
    }
}

/// API 响应码。业务码 0 表示成功，其余由服务端定义。
nonisolated struct Sub2APIResponseCode: Equatable, RawRepresentable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let success = Sub2APIResponseCode(rawValue: 0)
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
    case tokenExpired
    case notFound
    case networkError(String)
}

nonisolated enum Sub2APIGroupListResult: Equatable {
    case success(items: [Sub2APICapacityItem])
    case tokenExpired
    case networkError(String)
}

private nonisolated struct Sub2APIFetchError: Error {
    let message: String
}

// MARK: - 网络服务协议与实现

nonisolated protocol Sub2APIFetching: Sendable {
    func fetchCapacitySummary(baseURL: String, targetGroupID: Int, bearerKey: String) async -> Sub2APICapacityResult
    func fetchCapacityGroups(baseURL: String, bearerKey: String) async -> Sub2APIGroupListResult
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
                return .networkError(error.message)
            }

            return .networkError("未知错误")
        }

        guard response.code == .success, let items = response.data?.items else {
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
                return .networkError(error.message)
            }

            return .networkError("未知错误")
        }

        guard response.code == .success, let items = response.data?.items else {
            if response.indicatesTokenExpired {
                return .tokenExpired
            }

            return .networkError(response.message)
        }

        return .success(items: items)
    }

    private func fetchCapacityResponse(baseURL: String, bearerKey: String) async -> Result<Sub2APICapacityResponse, Sub2APIFetchError> {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard !normalizedBaseURL.isEmpty,
              let url = URL(string: "https://\(normalizedBaseURL)/api/v1/channel-monitors/capacity-summary")
        else {
            return .failure(Sub2APIFetchError(message: "无效的 Base URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let data: Data
        do {
            let (responseData, _) = try await urlSession.data(for: request)
            data = responseData
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
}

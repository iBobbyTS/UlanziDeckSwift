import Foundation

// MARK: - 请求结果

/// New API 余额结果。只有 subscription 与 usage 两个端点都成功且字段为
/// 有限数值时才会产出 `.success`；任一端点失败都不做半更新。
nonisolated enum NewAPIBalanceResult: Codable, Equatable {
    case success(remaining: Double)
    case unauthorized
    case networkError(String)

    /// 与 Sub2APIBalanceResult.displayValue 相同的显示规则：整数 0 位小数，
    /// 其他值按十进制四舍五入到 2 位（en_US_POSIX），负值不做 clamp。
    var displayValue: String? {
        guard case let .success(remaining) = self else { return nil }
        if remaining.rounded() == remaining {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), remaining)
        }
        // 先按 JSON 数值的十进制表示做四舍五入，避免 Double 对 12.345 这类值的
        // 二进制近似让 `String(format:)` 显示为 12.34。
        var decimal = Decimal(string: String(remaining), locale: Locale(identifier: "en_US_POSIX"))
            ?? Decimal(remaining)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 2, .plain)
        return String(
            format: "%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            NSDecimalNumber(decimal: rounded).doubleValue
        )
    }
}

// MARK: - 端点 URL

extension NewAPIBaseURL {
    /// `GET <base>/v1/dashboard/billing/subscription`，返回 `hard_limit_usd`。
    var billingSubscriptionURL: URL {
        url.appendingPathComponent("v1")
            .appendingPathComponent("dashboard")
            .appendingPathComponent("billing")
            .appendingPathComponent("subscription")
    }

    /// `GET <base>/v1/dashboard/billing/usage`，返回 `total_usage`（单位：美分）。
    var billingUsageURL: URL {
        url.appendingPathComponent("v1")
            .appendingPathComponent("dashboard")
            .appendingPathComponent("billing")
            .appendingPathComponent("usage")
    }
}

// MARK: - 网络服务协议与实现

nonisolated protocol NewAPIBalanceFetching: Sendable {
    func fetchBalance(baseURL: String, apiKey: String) async -> NewAPIBalanceResult
}

/// New API 余额查询：请求两个 billing 端点并按
/// `remaining = hard_limit_usd - total_usage / 100` 归一化。
/// 每个 New API 余额按键使用自己的 Base URL / API Key / 请求，
/// 不接入 Sub2API 数据来源图。
nonisolated struct NewAPIBalanceFetcher: NewAPIBalanceFetching {
    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval

    nonisolated init(urlSession: URLSession = .shared, timeoutSeconds: TimeInterval = 10) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
    }

    func fetchBalance(baseURL: String, apiKey: String) async -> NewAPIBalanceResult {
        let base: NewAPIBaseURL
        do {
            base = try NewAPIBaseURL(baseURL)
        } catch {
            return .networkError("无效的 Base URL")
        }

        let subscriptionResult = await fetchFiniteFieldValue(
            url: base.billingSubscriptionURL,
            apiKey: apiKey,
            fieldName: "hard_limit_usd",
            missingFieldMessage: "响应缺少有效额度上限"
        )
        let hardLimitUSD: Double
        switch subscriptionResult {
        case let .success(value):
            hardLimitUSD = value
        case let .failure(error):
            return error.resultValue
        }

        let usageResult = await fetchFiniteFieldValue(
            url: base.billingUsageURL,
            apiKey: apiKey,
            fieldName: "total_usage",
            missingFieldMessage: "响应缺少有效用量"
        )
        let totalUsage: Double
        switch usageResult {
        case let .success(value):
            totalUsage = value
        case let .failure(error):
            return error.resultValue
        }

        let remaining = hardLimitUSD - totalUsage / 100
        guard remaining.isFinite else {
            return .networkError("余额计算结果无效")
        }
        return .success(remaining: remaining)
    }

    private func fetchFiniteFieldValue(
        url: URL,
        apiKey: String,
        fieldName: String,
        missingFieldMessage: String
    ) async -> Result<Double, NewAPIBalanceEndpointError> {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeoutSeconds

        let data: Data
        do {
            data = try await AuthenticatedHTTPResponseLoader.data(for: request, urlSession: urlSession)
        } catch AuthenticatedHTTPResponseError.unauthorized {
            return .failure(.unauthorized)
        } catch {
            return .failure(.network(error.localizedDescription))
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.network("解析响应失败"))
        }
        guard let value = Self.doubleValue(object[fieldName]), value.isFinite else {
            return .failure(.network(missingFieldMessage))
        }
        return .success(value)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return number.doubleValue
        }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

private nonisolated enum NewAPIBalanceEndpointError: Error {
    case unauthorized
    case network(String)

    var resultValue: NewAPIBalanceResult {
        switch self {
        case .unauthorized:
            return .unauthorized
        case let .network(message):
            return .networkError(message)
        }
    }
}

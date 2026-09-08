import CoreFoundation
import Foundation

nonisolated protocol ZcodeConfigurationFileLoading: Sendable {
    func loadConfigurationData(
        configuration: DeckKeyCodexUsageConfiguration
    ) -> CodexAuthFileLoadResult
}

nonisolated struct SecurityScopedZcodeConfigurationFileLoader: ZcodeConfigurationFileLoading {
    func loadConfigurationData(
        configuration: DeckKeyCodexUsageConfiguration
    ) -> CodexAuthFileLoadResult {
        guard let bookmarkData = configuration.zcodeBookmarkData else {
            return configuration.zcodeConfigFilePath == nil ? .notSelected : .needsReselection
        }

        do {
            var isStale = false
            let fileURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: DeckKeyCodexUsageConfiguration.securityScopedBookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            return .success(try Data(contentsOf: fileURL))
        } catch {
            return .needsReselection
        }
    }
}

nonisolated protocol ZcodeUsageFetching: Sendable {
    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult
}

nonisolated struct ZcodeUsageFetcher: ZcodeUsageFetching {
    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval
    private let configurationFileLoader: ZcodeConfigurationFileLoading
    private let now: @Sendable () -> Date

    init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10,
        configurationFileLoader: ZcodeConfigurationFileLoading = SecurityScopedZcodeConfigurationFileLoader(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
        self.configurationFileLoader = configurationFileLoader
        self.now = now
    }

    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult {
        let configurationData: Data
        switch configurationFileLoader.loadConfigurationData(configuration: configuration) {
        case let .success(data): configurationData = data
        case .notSelected: return .authFileNotSelected
        case .needsReselection: return .authFileNeedsReselection
        }

        guard let root = try? JSONSerialization.jsonObject(with: configurationData) as? [String: Any]
        else {
            return .invalidAuthFile
        }
        guard let providers = root["provider"] as? [String: Any],
              let provider = providers["builtin:zai-coding-plan"] as? [String: Any],
              let options = provider["options"] as? [String: Any],
              let apiKey = Self.nonemptyString(options["apiKey"]),
              let baseURLString = Self.nonemptyString(options["baseURL"]),
              let requestURL = Self.usageURL(from: baseURLString)
        else {
            return .invalidConfiguration
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
              Self.businessRequestSucceeded(object),
              let responseData = object["data"] as? [String: Any],
              let limits = responseData["limits"] as? [[String: Any]]
        else {
            return .networkError("解析额度响应失败")
        }

        guard let weekly = limits.first(where: {
            ($0["type"] as? String) == "CREDIT_LIMIT"
                && Self.integer($0["unit"]) == 6
                && Self.integer($0["number"]) == 1
        }), let percentage = Self.finitePercentage(weekly["percentage"])
        else {
            return .missingWeeklyQuota
        }

        let reset = Self.resetTiming(
            fromUnixMilliseconds: weekly["nextResetTime"],
            now: now()
        )
        return .success(CodexUsageQuota(
            remainingPercent: min(100, max(0, Int((100 - percentage).rounded()))),
            resetAfterSeconds: reset?.afterSeconds ?? 0,
            resetAt: reset?.atSeconds,
            limitWindowSeconds: 604_800,
            usedPercent: percentage
        ))
    }

    static func usageURL(from baseURLString: String) -> URL? {
        guard let baseURL = URL(string: baseURLString),
              let scheme = baseURL.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = baseURL.host,
              !host.isEmpty
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = baseURL.port
        components.path = "/api/monitor/usage/quota/limit"
        return components.url
    }

    private static func businessRequestSucceeded(_ object: [String: Any]) -> Bool {
        guard object["success"] as? Bool == true else { return false }
        if let code = integer(object["code"]) {
            return code == 200
        }
        return true
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func finitePercentage(_ value: Any?) -> Double? {
        guard !isJSONBoolean(value) else { return nil }
        let number: Double?
        if let value = value as? NSNumber { number = value.doubleValue }
        else if let value = value as? String { number = Double(value) }
        else { number = nil }
        guard let number, number.isFinite, (0...100).contains(number) else { return nil }
        return number
    }

    private static func resetTiming(
        fromUnixMilliseconds value: Any?,
        now: Date
    ) -> (atSeconds: Int, afterSeconds: Int)? {
        guard !isJSONBoolean(value) else {
            return nil
        }
        let milliseconds: Double?
        if let value = value as? NSNumber { milliseconds = value.doubleValue }
        else if let value = value as? String { milliseconds = Double(value) }
        else { milliseconds = nil }
        guard let milliseconds,
              milliseconds.isFinite,
              milliseconds >= 0
        else {
            return nil
        }

        let resetTimestamp = milliseconds / 1_000
        guard let resetAtSeconds = Int(exactly: resetTimestamp.rounded(.down)) else {
            return nil
        }
        let remainingSeconds = min(
            Double(Int.max),
            max(0, resetTimestamp - now.timeIntervalSince1970)
        )
        return (
            atSeconds: resetAtSeconds,
            afterSeconds: Int(exactly: remainingSeconds.rounded(.down)) ?? Int.max
        )
    }

    private static func isJSONBoolean(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
